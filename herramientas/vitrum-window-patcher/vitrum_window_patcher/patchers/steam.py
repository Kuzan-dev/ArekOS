"""
Steam Window Controls and Vitrum Decoration Patcher.
"""

import os
import shutil
import subprocess
from pathlib import Path
from typing import Tuple

from ..constants import STEAM_NATIVE_DIR, STEAM_FLATPAK_DIR, VITRUM_KDE_DIR, KWINRULESRC_PATH


def is_installed() -> bool:
    if shutil.which("steam") or STEAM_NATIVE_DIR.exists() or STEAM_FLATPAK_DIR.exists():
        return True
    return False


def is_patched() -> bool:
    # Check KWin rule
    has_kwin_rule = False
    if KWINRULESRC_PATH.exists():
        content = KWINRULESRC_PATH.read_text(encoding="utf-8", errors="ignore")
        if "steam-rule" in content:
            has_kwin_rule = True

    # Check Adwaita for Steam
    has_theme = False
    for steam_dir in [STEAM_NATIVE_DIR, STEAM_FLATPAK_DIR]:
        if (steam_dir / "steamui/adwaita/config.css").exists():
            has_theme = True
            break

    return has_kwin_rule and has_theme


def patch() -> Tuple[bool, str]:
    script_path = VITRUM_KDE_DIR / "scripts/vitrum-steam"
    if not script_path.exists():
        return False, f"Script no encontrado: {script_path}"

    try:
        res = subprocess.run(["bash", str(script_path)], capture_output=True, text=True)
        if res.returncode == 0:
            # Reconfigure KWin
            subprocess.run(["qdbus-qt6", "org.kde.KWin", "/KWin", "reconfigure"], capture_output=True)
            return True, "Steam parchado con éxito con semáforos macOS y bordes Vitrum de 10px."
        else:
            return False, f"Error al ejecutar parche de Steam: {res.stderr}"
    except Exception as e:
        return False, str(e)


def revert() -> Tuple[bool, str]:
    try:
        # 1. Remove KWin rules
        if KWINRULESRC_PATH.exists():
            import configparser
            cp = configparser.ConfigParser(interpolation=None)
            cp.read(str(KWINRULESRC_PATH), encoding="utf-8")
            
            rules = cp.get("General", "rules", fallback="").split(",")
            rules = [r.strip() for r in rules if r.strip() not in ("steam-rule", "steam-bigpicture-rule")]
            
            if "General" in cp:
                cp["General"]["rules"] = ",".join(rules)
                cp["General"]["count"] = str(len(rules))
            if "steam-rule" in cp:
                cp.remove_section("steam-rule")
            if "steam-bigpicture-rule" in cp:
                cp.remove_section("steam-bigpicture-rule")

            with open(KWINRULESRC_PATH, "w", encoding="utf-8") as f:
                cp.write(f)

        # 2. Remove Adwaita theme
        for steam_dir in [STEAM_NATIVE_DIR, STEAM_FLATPAK_DIR]:
            adw_dir = steam_dir / "steamui/adwaita"
            if adw_dir.exists():
                shutil.rmtree(adw_dir)

        # Reconfigure KWin
        subprocess.run(["qdbus-qt6", "org.kde.KWin", "/KWin", "reconfigure"], capture_output=True)
        return True, "Decoración y controles de Steam revertidos al estado original."
    except Exception as e:
        return False, str(e)
