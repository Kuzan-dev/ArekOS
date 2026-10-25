"""
Visual Studio Code / VSCodium Native Titlebar Patcher.
"""

import json
import shutil
from pathlib import Path
from typing import Tuple, List

from ..constants import VSCODE_NATIVE_SETTINGS, VSCODE_FLATPAK_SETTINGS, VSCODIUM_SETTINGS


def get_settings_files() -> List[Path]:
    files = []
    for p in [VSCODE_NATIVE_SETTINGS, VSCODE_FLATPAK_SETTINGS, VSCODIUM_SETTINGS]:
        if p.exists():
            files.append(p)
    return files


def is_installed() -> bool:
    if shutil.which("code") or shutil.which("codium") or get_settings_files():
        return True
    return False


def is_patched() -> bool:
    files = get_settings_files()
    if not files:
        return False
    for p in files:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            if data.get("window.titleBarStyle") != "native":
                return False
        except Exception:
            return False
    return True


def patch() -> Tuple[bool, str]:
    files = get_settings_files()
    if not files:
        # If VS Code directory exists, create settings.json
        for parent_dir in [VSCODE_NATIVE_SETTINGS.parent, VSCODE_FLATPAK_SETTINGS.parent]:
            if parent_dir.parent.exists():
                parent_dir.mkdir(parents=True, exist_ok=True)
                sfile = parent_dir / "settings.json"
                sfile.write_text(json.dumps({"window.titleBarStyle": "native"}, indent=2))
                files.append(sfile)
                break

    if not files:
        return False, "No se encontró configuración de VS Code o VSCodium."

    patched = 0
    for p in files:
        try:
            data = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
            data["window.titleBarStyle"] = "native"
            p.write_text(json.dumps(data, indent=2), encoding="utf-8")
            patched += 1
        except Exception as e:
            return False, f"Error parchando VS Code: {e}"

    return True, f"VS Code configurado con barra nativa y semáforos Vitrum ({patched} archivo(s))."


def revert() -> Tuple[bool, str]:
    files = get_settings_files()
    if not files:
        return False, "No se encontró configuración de VS Code o VSCodium."

    reverted = 0
    for p in files:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            if "window.titleBarStyle" in data:
                data["window.titleBarStyle"] = "custom"
                p.write_text(json.dumps(data, indent=2), encoding="utf-8")
                reverted += 1
        except Exception as e:
            return False, f"Error revirtiendo VS Code: {e}"

    return True, "VS Code restaurado a su barra de título interna."
