"""
Vitrum Native Traffic Lights (Semáforos de macOS para KDE/Vitrum).
Exact implementation matching Vitrum's window decoration:
- 12 px diameter with 1 px darker rim
- 20 px pitch between centers, first center at 14 px from left
- ×, −, and zoom/fullscreen glyphs appear on all 3 buttons simultaneously on hover
- Inactive state turns gray (#4E4E50 / #3C3C3E)
"""

import math
import cairo
import gi

gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk


class VitrumTrafficLights(Gtk.DrawingArea):
    def __init__(self, window: Gtk.Window):
        super().__init__()
        self.window = window
        self.set_size_request(54, 16)
        self.set_valign(Gtk.Align.CENTER)
        self.set_margin_start(14)
        self.set_margin_end(12)

        self.hovered = False
        self.pressed_idx = -1

        # Color definitions from Vitrum macOS Monterey specification
        self.fills = [
            (1.0, 0.373, 0.341),   # #FF5F57 (Close)
            (0.996, 0.737, 0.180),   # #FEBC2E (Minimize)
            (0.157, 0.784, 0.251),   # #28C840 (Zoom/Maximize)
        ]
        self.rims = [
            (0.878, 0.267, 0.243),   # #E0443E
            (0.871, 0.631, 0.137),   # #DEA123
            (0.102, 0.671, 0.161),   # #1AAB29
        ]
        self.glyphs = [
            (0.302, 0.0, 0.0),       # #4D0000
            (0.600, 0.341, 0.0),     # #995700
            (0.0, 0.396, 0.0),       # #006500
        ]

        # Inactive colors
        self.fill_inactive = (0.306, 0.306, 0.314)  # #4E4E50
        self.rim_inactive = (0.235, 0.235, 0.243)   # #3C3C3E

        self.set_draw_func(self._draw)

        # Motion controller for hover
        motion = Gtk.EventControllerMotion.new()
        motion.connect("enter", self._on_enter)
        motion.connect("leave", self._on_leave)
        self.add_controller(motion)

        # Click gesture
        click = Gtk.GestureClick.new()
        click.connect("pressed", self._on_pressed)
        click.connect("released", self._on_released)
        self.add_controller(click)

        # Track window focus
        if hasattr(self.window, "connect"):
            self.window.connect("notify::is-active", lambda *a: self.queue_draw())

    def _draw(self, area, cr: cairo.Context, width: int, height: int):
        is_active = self.window.is_active() if hasattr(self.window, "is_active") else True
        colored = is_active or self.hovered

        cy = height / 2.0

        for i in range(3):
            cx = 6.0 + (i * 20.0)
            is_pressed = (self.pressed_idx == i)

            # Determine colors
            if colored:
                fill_col = self.fills[i]
                rim_col = self.rims[i]
            else:
                fill_col = self.fill_inactive
                rim_col = self.rim_inactive

            # If pressed, slightly darken
            if is_pressed:
                fill_col = tuple(c * 0.82 for c in fill_col)
                rim_col = tuple(c * 0.82 for c in rim_col)

            # Draw Rim (outer 1px darker border, radius 6)
            cr.set_source_rgb(*rim_col)
            cr.arc(cx, cy, 6.0, 0, 2 * math.pi)
            cr.fill()

            # Draw Fill (inner circle, radius 5)
            cr.set_source_rgb(*fill_col)
            cr.arc(cx, cy, 5.0, 0, 2 * math.pi)
            cr.fill()

            # Draw Glyphs if hovered (all 3 appear simultaneously as in Vitrum/macOS)
            if self.hovered:
                cr.set_source_rgba(self.glyphs[i][0], self.glyphs[i][1], self.glyphs[i][2], 0.85)
                cr.set_line_width(1.2)
                cr.set_line_cap(cairo.LINE_CAP_ROUND)
                
                bx = cx - 6.0
                by = cy - 6.0

                if i == 0:
                    # Close '×'
                    cr.move_to(bx + 3.7, by + 3.7)
                    cr.line_to(bx + 8.3, by + 8.3)
                    cr.move_to(bx + 8.3, by + 3.7)
                    cr.line_to(bx + 3.7, by + 8.3)
                    cr.stroke()
                elif i == 1:
                    # Minimize '−'
                    cr.rectangle(bx + 2.6, by + 5.4, 6.8, 1.2)
                    cr.fill()
                else:
                    # Zoom / Maximize (two diagonal triangles)
                    cr.move_to(bx + 3.2, by + 3.2)
                    cr.line_to(bx + 7.8, by + 3.2)
                    cr.line_to(bx + 3.2, by + 7.8)
                    cr.close_path()
                    cr.fill()

                    cr.move_to(bx + 8.8, by + 8.8)
                    cr.line_to(bx + 4.2, by + 8.8)
                    cr.line_to(bx + 8.8, by + 4.2)
                    cr.close_path()
                    cr.fill()

    def _get_button_at_x(self, x: float) -> int:
        for i in range(3):
            cx = 6.0 + (i * 20.0)
            if abs(x - cx) <= 8.0:
                return i
        return -1

    def _on_enter(self, controller, x, y):
        self.hovered = True
        self.queue_draw()

    def _on_leave(self, controller):
        self.hovered = False
        self.pressed_idx = -1
        self.queue_draw()

    def _on_pressed(self, gesture, n_press, x, y):
        idx = self._get_button_at_x(x)
        if idx != -1:
            self.pressed_idx = idx
            self.queue_draw()

    def _on_released(self, gesture, n_press, x, y):
        idx = self._get_button_at_x(x)
        pressed = self.pressed_idx
        self.pressed_idx = -1
        self.queue_draw()

        if idx == pressed and idx != -1:
            if idx == 0:
                self.window.close()
            elif idx == 1:
                self.window.minimize()
            elif idx == 2:
                if self.window.is_maximized():
                    self.window.unmaximize()
                else:
                    self.window.maximize()
