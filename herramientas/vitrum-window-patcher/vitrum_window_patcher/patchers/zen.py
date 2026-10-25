"""
Zen Browser Window Controls Patcher (userChrome.css macOS Semáforos).
"""

import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Tuple

from ..constants import ZEN_USERCHROME_SRC, ZEN_FLATPAK_DIR, ZEN_NATIVE_DIR


def is_installed() -> bool:
    if ZEN_FLATPAK_DIR.exists() or ZEN_NATIVE_DIR.exists():
        return True
    try:
        res = subprocess.run(["flatpak", "info", "app.zen_browser.zen"], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False


def get_profile_dirs() -> List[Path]:
    profiles = []
    for base in [ZEN_FLATPAK_DIR, ZEN_NATIVE_DIR]:
        if base.exists():
            for p in base.iterdir():
                if p.is_dir() and ((p / "prefs.js").exists() or (p / "times.json").exists()):
                    profiles.append(p)
    return profiles


def is_patched() -> bool:
    profiles = get_profile_dirs()
    if not profiles:
        return False
    for p in profiles:
        css_file = p / "chrome/userChrome.css"
        if not css_file.exists():
            return False
        # Check if css contains macOS traffic lights
        content = css_file.read_text(encoding="utf-8", errors="ignore")
        if "--zen-icon-macos-close" not in content:
            return False
    return True


def patch() -> Tuple[bool, str]:
    if not ZEN_USERCHROME_SRC.exists():
        return False, f"Archivo fuente no encontrado: {ZEN_USERCHROME_SRC}"

    profiles = get_profile_dirs()
    if not profiles:
        return False, "No se encontraron perfiles activos de Zen Browser."

    # 1. Flatpak permission overrides
    try:
        subprocess.run([
            "flatpak", "override", "--user",
            "--filesystem=xdg-config/gtk-3.0:ro",
            "--filesystem=xdg-config/gtk-4.0:ro",
            "app.zen_browser.zen"
        ], capture_output=True)
    except Exception:
        pass

    # 2. Copy userChrome.css to profiles and enable stylesheet pref
    patched_count = 0
    for p in profiles:
        try:
            chrome_dir = p / "chrome"
            chrome_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ZEN_USERCHROME_SRC, chrome_dir / "userChrome.css")

            user_js = p / "user.js"
            pref_line = 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n'
            existing = user_js.read_text(encoding="utf-8", errors="ignore") if user_js.exists() else ""
            if "legacyUserProfileCustomizations.stylesheets" not in existing:
                with open(user_js, "a", encoding="utf-8") as f:
                    f.write(pref_line)
            patched_count += 1
        except Exception as e:
            return False, f"Error parchando perfil {p.name}: {e}"

    return True, f"Zen Browser parchado con éxito ({patched_count} perfil(es)). Reinicia el navegador para aplicar."


def revert() -> Tuple[bool, str]:
    profiles = get_profile_dirs()
    if not profiles:
        return False, "No se encontraron perfiles de Zen Browser."

    reverted_count = 0
    for p in profiles:
        css_file = p / "chrome/userChrome.css"
        if css_file.exists():
            try:
                css_file.unlink()
                reverted_count += 1
            except Exception as e:
                return False, f"Error revirtiendo perfil {p.name}: {e}"

    return True, f"Semáforos de Zen Browser revertidos ({reverted_count} perfil(es))."
