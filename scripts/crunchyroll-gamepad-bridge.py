#!/usr/bin/env python3
"""
Streaming WebApps Gamepad Bridge (Disney+, Max / HBO Max, etc.)
Translates Xbox / Generic Gamepad events into Keyboard & Mouse events for 10-foot streaming UI navigation.
"""

import sys
import time
import math
import subprocess
import threading
import signal
import evdev
from evdev import UInput, ecodes as e

RUNNING = True

def signal_handler(signum, frame):
    global RUNNING
    RUNNING = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

CAPABILITIES = {
    e.EV_KEY: [
        e.KEY_UP, e.KEY_DOWN, e.KEY_LEFT, e.KEY_RIGHT,
        e.KEY_ENTER, e.KEY_SPACE, e.KEY_ESC, e.KEY_BACKSPACE,
        e.KEY_F, e.KEY_M, e.KEY_TAB, e.BTN_LEFT, e.BTN_RIGHT
    ],
    e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL]
}

def is_chrome_running():
    try:
        res = subprocess.run(["pgrep", "-f", "chrome"], stdout=subprocess.DEVNULL)
        return res.returncode == 0
    except Exception:
        return True

def is_gamepad(device):
    name = device.name.lower()
    if "streaming" in name or "disneyplus" in name or "virtual" in name:
        return False
    caps = device.capabilities()
    if e.EV_KEY in caps:
        keys = caps[e.EV_KEY]
        if e.BTN_A in keys or e.BTN_SOUTH in keys or e.BTN_GAMEPAD in keys:
            return True
    return False

def find_gamepad():
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
            if is_gamepad(dev):
                return dev
        except Exception:
            continue
    return None

class GamepadController:
    def __init__(self, ui, dev):
        self.ui = ui
        self.dev = dev
        # Left stick
        self.stick_l_x = 0
        self.stick_l_y = 0
        # Right stick
        self.stick_r_x = 0
        self.stick_r_y = 0
        
        self.rt_pressed = False
        self.lt_pressed = False
        self.running = True

        # Trigger threshold detection
        self.trigger_threshold = 30
        caps = dev.capabilities()
        if e.EV_ABS in caps:
            for item in caps[e.EV_ABS]:
                abs_code = item[0]
                abs_info = item[1]
                if abs_code in (e.ABS_RZ, e.ABS_GAS, 5, 9):
                    if abs_info.max > 255:
                        self.trigger_threshold = int(abs_info.max * 0.2)
                    else:
                        self.trigger_threshold = 30
                    break

    def pulse_key(self, keycode):
        self.ui.write(e.EV_KEY, keycode, 1)
        self.ui.syn()
        time.sleep(0.04)
        self.ui.write(e.EV_KEY, keycode, 0)
        self.ui.syn()

    def mouse_worker(self):
        DEADZONE = 4000
        MAX_VAL = 32767.0
        MAX_SPEED = 24.0

        while self.running and RUNNING:
            if not is_chrome_running():
                time.sleep(1.0)
                continue

            # Check both sticks - take whichever has input
            lx = self.stick_l_x if abs(self.stick_l_x) > DEADZONE else 0
            ly = self.stick_l_y if abs(self.stick_l_y) > DEADZONE else 0
            rx = self.stick_r_x if abs(self.stick_r_x) > DEADZONE else 0
            ry = self.stick_r_y if abs(self.stick_r_y) > DEADZONE else 0

            # Prioritize stick with largest deflection
            x_val = rx if abs(rx) >= abs(lx) else lx
            y_val = ry if abs(ry) >= abs(ly) else ly

            dx = 0
            dy = 0
            if abs(x_val) > DEADZONE:
                norm_x = (abs(x_val) - DEADZONE) / (MAX_VAL - DEADZONE)
                dx = math.copysign(pow(min(norm_x, 1.0), 1.5) * MAX_SPEED, x_val)
            if abs(y_val) > DEADZONE:
                norm_y = (abs(y_val) - DEADZONE) / (MAX_VAL - DEADZONE)
                dy = math.copysign(pow(min(norm_y, 1.0), 1.5) * MAX_SPEED, y_val)

            if dx != 0 or dy != 0:
                self.ui.write(e.EV_REL, e.REL_X, int(dx))
                self.ui.write(e.EV_REL, e.REL_Y, int(dy))
                self.ui.syn()

            time.sleep(0.016)

    def run(self):
        mouse_thread = threading.Thread(target=self.mouse_worker, daemon=True)
        mouse_thread.start()

        BTN_MAP = {
            e.BTN_B: (e.KEY_BACKSPACE, e.KEY_ESC),
            e.BTN_EAST: (e.KEY_BACKSPACE, e.KEY_ESC),
            e.BTN_X: (e.KEY_SPACE,),
            e.BTN_NORTH: (e.KEY_SPACE,),
            e.BTN_Y: (e.KEY_F,),
            e.BTN_WEST: (e.KEY_F,),
            e.BTN_START: (e.KEY_SPACE,),
            e.BTN_SELECT: (e.KEY_ESC,),
            e.BTN_MODE: (e.KEY_ESC,),
            e.BTN_TL: (e.KEY_LEFT,),
            e.BTN_TR: (e.KEY_RIGHT,),
            e.BTN_THUMBL: (e.KEY_TAB,),
            e.BTN_THUMBR: (e.BTN_LEFT,),
        }

        try:
            for event in self.dev.read_loop():
                if not RUNNING:
                    break

                # Ignore events if Chrome/streaming webapp is closed
                if not is_chrome_running():
                    time.sleep(0.5)
                    continue

                if event.type == e.EV_KEY:
                    # Button A: Send BOTH Mouse Left Click AND Enter
                    if event.code in (e.BTN_A, e.BTN_SOUTH, 304):
                        self.ui.write(e.EV_KEY, e.BTN_LEFT, event.value)
                        self.ui.write(e.EV_KEY, e.KEY_ENTER, event.value)
                        self.ui.syn()
                    elif event.code in BTN_MAP:
                        targets = BTN_MAP[event.code]
                        for target in targets:
                            self.ui.write(e.EV_KEY, target, event.value)
                        self.ui.syn()

                elif event.type == e.EV_ABS:
                    # D-pad (cruceta)
                    if event.code == e.ABS_HAT0X:
                        if event.value == -1:
                            self.pulse_key(e.KEY_LEFT)
                        elif event.value == 1:
                            self.pulse_key(e.KEY_RIGHT)
                    elif event.code == e.ABS_HAT0Y:
                        if event.value == -1:
                            self.pulse_key(e.KEY_UP)
                        elif event.value == 1:
                            self.pulse_key(e.KEY_DOWN)

                    # Left Analog Stick (ejes 0 y 1)
                    elif event.code in (e.ABS_X, 0):
                        self.stick_l_x = event.value
                    elif event.code in (e.ABS_Y, 1):
                        self.stick_l_y = event.value

                    # Right Analog Stick (ejes 3 y 4)
                    elif event.code in (e.ABS_RX, 3):
                        self.stick_r_x = event.value
                    elif event.code in (e.ABS_RY, 4):
                        self.stick_r_y = event.value

                    # Right Trigger (RT) -> Mouse Left Click
                    elif event.code in (e.ABS_RZ, e.ABS_GAS, 5, 9):
                        is_down = event.value > self.trigger_threshold
                        if is_down != self.rt_pressed:
                            self.rt_pressed = is_down
                            self.ui.write(e.EV_KEY, e.BTN_LEFT, 1 if is_down else 0)
                            self.ui.syn()

                    # Left Trigger (LT) -> Mouse Right Click
                    elif event.code in (e.ABS_Z, e.ABS_BRAKE, 2, 10):
                        is_down = event.value > self.trigger_threshold
                        if is_down != self.lt_pressed:
                            self.lt_pressed = is_down
                            self.ui.write(e.EV_KEY, e.BTN_RIGHT, 1 if is_down else 0)
                            self.ui.syn()

        except Exception:
            pass
        finally:
            self.running = False


def main():
    try:
        ui = UInput(CAPABILITIES, name="Streaming-Virtual-Remote")
    except Exception as err:
        sys.exit(1)

    while RUNNING:
        gamepad = find_gamepad()
        if gamepad:
            controller = GamepadController(ui, gamepad)
            controller.run()
        time.sleep(1.0)

    ui.close()

if __name__ == "__main__":
    main()
