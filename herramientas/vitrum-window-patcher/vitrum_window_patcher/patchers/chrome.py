"""
Google Chrome / Chromium System Titlebar & Vitrum Semáforos Patcher.
Enables native Vitrum macOS window decorations (semáforos on the left + 10px corners)
in Google Chrome on KDE Plasma.
"""

import os
import json
import shutil
import subprocess
import configparser
from pathlib import Path
from typing import Tuple, List

from ..constants import CHROME_FLATPAK_PREFS, CHROME_NATIVE_PREFS, KWINRULESRC_PATH, HOME

CHROME_FLATPAK_FLAGS = HOME / ".var/app/com.google.Chrome/config/chrome-flags.conf"
CHROME_NATIVE_FLAGS = HOME / ".config/chrome-flags.conf"


def get_pref_files() -> List[Path]:
    files = []
    for p in [CHROME_FLATPAK_PREFS, CHROME_NATIVE_PREFS]:
        if p.exists():
            files.append(p)
    return files


def is_installed() -> bool:
    if shutil.which("google-chrome") or shutil.which("chromium") or get_pref_files():
        return True
    try:
        res = subprocess.run(["flatpak", "info", "com.google.Chrome"], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False


def is_patched() -> bool:
    pref_files = get_pref_files()
    if not pref_files:
        return False

    # Check preferences
    for p in pref_files:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            if data.get("browser", {}).get("custom_chrome_frame") is not False:
                return False
        except Exception:
            return False

    # Check KWin rule
    if KWINRULESRC_PATH.exists():
        content = KWINRULESRC_PATH.read_text(encoding="utf-8", errors="ignore")
        if "google-chrome-rule" not in content:
            return False

    # Check flags
    if not CHROME_FLATPAK_FLAGS.exists() and not CHROME_NATIVE_FLAGS.exists():
        return False

    return True


def patch() -> Tuple[bool, str]:
    pref_files = get_pref_files()
    if not pref_files:
        return False, "No se encontró el archivo de preferencias de Google Chrome."

    # 1. Flatpak permission overrides (so Chrome can read GTK layout)
    try:
        subprocess.run([
            "flatpak", "override", "--user",
            "--filesystem=xdg-config/gtk-3.0:ro",
            "--filesystem=xdg-config/gtk-4.0:ro",
            "com.google.Chrome"
        ], capture_output=True)
    except Exception:
        pass

    # 2. Add / Update KWin rule for Chrome
    try:
        cp = configparser.ConfigParser(interpolation=None)
        if KWINRULESRC_PATH.exists():
            cp.read(str(KWINRULESRC_PATH), encoding="utf-8")
        if "General" not in cp:
            cp["General"] = {"count": "0", "rules": ""}

        rules_list = [r.strip() for r in cp.get("General", "rules", fallback="").split(",") if r.strip()]
        if "google-chrome-rule" not in rules_list:
            rules_list.append("google-chrome-rule")
        cp["General"]["rules"] = ",".join(rules_list)
        cp["General"]["count"] = str(len(rules_list))

        cp["google-chrome-rule"] = {
            "Description": "Google Chrome Vitrum Decoration",
            "noborder": "false",
            "noborderrule": "2",
            "types": "1",
            "wmclass": "chrome",
            "wmclasscomplete": "false",
            "wmclassmatch": "2"
        }

        with open(KWINRULESRC_PATH, "w", encoding="utf-8") as f:
            cp.write(f)

        subprocess.run(["qdbus-qt6", "org.kde.KWin", "/KWin", "reconfigure"], capture_output=True)
    except Exception as e:
        return False, f"Error configurando regla KWin para Chrome: {e}"

    # 3. Write chrome-flags.conf (--ozone-platform=x11)
    # This enables KWin server-side decorations with the native Vitrum theme on KDE Plasma
    for flag_path in [CHROME_FLATPAK_FLAGS, CHROME_NATIVE_FLAGS]:
        try:
            flag_path.parent.mkdir(parents=True, exist_ok=True)
            flag_path.write_text("--ozone-platform=x11\n", encoding="utf-8")
        except Exception:
            pass

    # 4. Set custom_chrome_frame = False in Preferences
    patched = 0
    for p in pref_files:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            if "browser" not in data:
                data["browser"] = {}
            data["browser"]["custom_chrome_frame"] = False
            p.write_text(json.dumps(data, indent=2), encoding="utf-8")
            patched += 1
        except Exception as e:
            return False, f"Error parchando preferencias de Chrome: {e}"

    return True, f"Google Chrome parchado con éxito con semáforos nativos de Vitrum ({patched} perfil). Cierra completamente Chrome y vuelve a abrirlo."


def revert() -> Tuple[bool, str]:
    pref_files = get_pref_files()

    # 1. Remove chrome-flags.conf
    for flag_path in [CHROME_FLATPAK_FLAGS, CHROME_NATIVE_FLAGS]:
        if flag_path.exists():
            try:
                flag_path.unlink()
            except Exception:
                pass

    # 2. Remove KWin rule
    try:
        if KWINRULESRC_PATH.exists():
            cp = configparser.ConfigParser(interpolation=None)
            cp.read(str(KWINRULESRC_PATH), encoding="utf-8")
            rules_list = [r.strip() for r in cp.get("General", "rules", fallback="").split(",") if r.strip()]
            rules_list = [r for r in rules_list if r != "google-chrome-rule"]
            cp["General"]["rules"] = ",".join(rules_list)
            cp["General"]["count"] = str(len(rules_list))
            if "google-chrome-rule" in cp:
                cp.remove_section("google-chrome-rule")
            with open(KWINRULESRC_PATH, "w", encoding="utf-8") as f:
                cp.write(f)
            subprocess.run(["qdbus-qt6", "org.kde.KWin", "/KWin", "reconfigure"], capture_output=True)
    except Exception:
        pass

    # 3. Restore custom_chrome_frame = True
    for p in pref_files:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            if "browser" in data:
                data["browser"]["custom_chrome_frame"] = True
                p.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except Exception:
            pass

    return True, "Semáforos de Google Chrome revertidos al marco predeterminado."
