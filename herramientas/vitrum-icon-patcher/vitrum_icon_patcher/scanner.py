"""
Desktop Application Scanner and Patcher for Vitrum Icon Patcher.
"""

import os
import re
import json
import shutil
import subprocess
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Optional, Dict

from .constants import (
    SYSTEM_DESKTOP_DIRS,
    USER_APPLICATIONS_DIR,
    WHITESUR_SCALABLE_DIR,
    HICOLOR_SCALABLE_DIR,
    HICOLOR_512_DIR,
    HICOLOR_256_DIR,
    VITRUM_ICONOS_DIR,
    BACKUP_FILE,
    CONFIG_DIR
)
from .engine import find_icon_path, is_icon_already_squircle, save_icon_bundle


@dataclass
class AppInfo:
    id: str  # e.g. "quiver-launcher.desktop"
    name: str
    icon_name: str
    icon_path: Optional[str]
    desktop_path: str
    is_patched: bool
    category: str
    is_user_desktop: bool
    is_pwa: bool
    is_game: bool


def slugify(text: str) -> str:
    """Creates a clean filename slug from an app name."""
    text = text.lower()
    text = re.sub(r'[\+\(\)\:\'\"\!\@\#\$\%\^\&\*\=\[\]\{\}\<\>\?\/\\\|]', '', text)
    text = re.sub(r'\s+', '-', text.strip())
    text = re.sub(r'-+', '-', text)
    return text.strip("-") or "app-icon"


def load_history() -> Dict[str, dict]:
    """Loads backup/patch history."""
    if BACKUP_FILE.exists():
        try:
            return json.loads(BACKUP_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_history(history: Dict[str, dict]):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    BACKUP_FILE.write_text(json.dumps(history, indent=2), encoding="utf-8")


def detect_category(categories_str: str, desktop_id: str, app_name: str) -> tuple[str, bool, bool]:
    cat_lower = categories_str.lower()
    id_lower = desktop_id.lower()
    name_lower = app_name.lower()

    is_pwa = "chrome-" in id_lower or "msedge-" in id_lower or "brave-" in id_lower or "pwa" in id_lower
    is_game = ("game" in cat_lower or "steam" in id_lower or "heroic" in id_lower or 
               "lutris" in id_lower or "bottles" in id_lower or "launcher" in id_lower or
               "juego" in cat_lower or "boilr" in id_lower)

    if is_game:
        return "Juegos", is_pwa, True
    elif is_pwa:
        return "Web / PWA", True, False
    elif "development" in cat_lower or "ide" in cat_lower:
        return "Desarrollo", is_pwa, is_game
    elif "audiovideo" in cat_lower or "audio" in cat_lower or "video" in cat_lower or "multimedia" in cat_lower:
        return "Multimedia", is_pwa, is_game
    elif "network" in cat_lower or "webbrowser" in cat_lower or "internet" in cat_lower:
        return "Internet", is_pwa, is_game
    elif "graphics" in cat_lower:
        return "Gráficos", is_pwa, is_game
    elif "system" in cat_lower or "settings" in cat_lower:
        return "Sistema", is_pwa, is_game
    else:
        return "Utilidades", is_pwa, is_game


def parse_desktop_file(path: str) -> Optional[dict]:
    """Parses a .desktop file manually to preserve accurate localized strings and lines."""
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
            
        in_entry = False
        data = {}
        for line in lines:
            line = line.strip()
            if line.startswith("[Desktop Entry]"):
                in_entry = True
                continue
            elif line.startswith("[") and in_entry:
                break
            if in_entry and "=" in line and not line.startswith("#"):
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip()
                # prioritize Name over Name[es] or vice versa if current lang is Spanish
                if key == "Name" and "Name" not in data:
                    data["Name"] = val
                elif key == "Name[es]":
                    data["Name"] = val  # Spanish override
                elif key not in data:
                    data[key] = val
        return data
    except Exception:
        return None


def scan_all_apps() -> List[AppInfo]:
    """Scans all installed applications and returns list of AppInfo."""
    apps: Dict[str, AppInfo] = {}
    history = load_history()

    for desktop_dir in SYSTEM_DESKTOP_DIRS:
        d = Path(desktop_dir)
        if not d.exists():
            continue

        for desktop_file in d.glob("*.desktop"):
            base_id = desktop_file.name
            # If already seen from user directory (~/.local/share/applications), skip system duplicate
            if base_id in apps:
                continue

            entry = parse_desktop_file(str(desktop_file))
            if not entry:
                continue

            # Skip hidden applications
            if entry.get("NoDisplay", "false").lower() == "true":
                continue

            name = entry.get("Name", "")
            icon_name = entry.get("Icon", "")
            if not name or not icon_name:
                continue

            categories = entry.get("Categories", "")
            category, is_pwa, is_game = detect_category(categories, base_id, name)
            
            icon_path = find_icon_path(icon_name)
            
            # Check if patched either through history or squircle geometry
            is_patched = (base_id in history) or is_icon_already_squircle(icon_name)
            is_user = str(desktop_file.parent) == str(USER_APPLICATIONS_DIR)

            apps[base_id] = AppInfo(
                id=base_id,
                name=name,
                icon_name=icon_name,
                icon_path=icon_path,
                desktop_path=str(desktop_file),
                is_patched=is_patched,
                category=category,
                is_user_desktop=is_user,
                is_pwa=is_pwa,
                is_game=is_game
            )

    result = list(apps.values())
    # Sort: unpatched first, then alphabetically by name
    result.sort(key=lambda x: (x.is_patched, x.name.lower()))
    return result


def refresh_system_caches():
    """Notifies KDE Plasma, GTK, and desktop database about icon updates."""
    USER_APPLICATIONS_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run(["update-desktop-database", str(USER_APPLICATIONS_DIR)], capture_output=True)
    
    whitesur_dir = WHITESUR_SCALABLE_DIR.parent.parent
    if whitesur_dir.exists():
        subprocess.run(["gtk-update-icon-cache", "-f", "-t", str(whitesur_dir)], capture_output=True)
        
    hicolor_dir = HICOLOR_SCALABLE_DIR.parent.parent
    if hicolor_dir.exists():
        subprocess.run(["gtk-update-icon-cache", "-f", "-t", str(hicolor_dir)], capture_output=True)

    # Refresh KDE Plasma Sycoca cache so Launchpad updates immediately
    subprocess.run(["kbuildsycoca6", "--noincremental"], capture_output=True)

    # Restart vitrum-shell so the custom Vitrum Launchpad and Dock reload icon cache
    subprocess.run(["systemctl", "--user", "restart", "vitrum-shell"], capture_output=True)


def patch_app_icon(app: AppInfo, svg_content: str, custom_slug: Optional[str] = None) -> tuple[bool, str]:
    """
    Applies the squircle patch to an application.
    """
    try:
        slug = custom_slug or slugify(app.name)
        
        # 1. Save icon bundle
        ok, msg = save_icon_bundle(svg_content, slug)
        if not ok:
            return False, f"Error al guardar ícono: {msg}"

        # 2. Determine target desktop file in ~/.local/share/applications
        user_desktop_path = USER_APPLICATIONS_DIR / app.id
        history = load_history()

        # Backup original state if not already in history
        if app.id not in history:
            history[app.id] = {
                "name": app.name,
                "original_icon": app.icon_name,
                "original_desktop_path": app.desktop_path,
                "created_user_override": not app.is_user_desktop,
                "patched_slug": slug
            }
            save_history(history)

        # 3. Read original desktop content and update Icon= line
        content = Path(app.desktop_path).read_text(encoding="utf-8", errors="ignore")
        
        # Replace Icon= line in [Desktop Entry]
        lines = content.splitlines()
        new_lines = []
        replaced_icon = False
        in_entry = False

        for line in lines:
            if line.strip().startswith("[Desktop Entry]"):
                in_entry = True
                new_lines.append(line)
                continue
            elif line.strip().startswith("[") and in_entry:
                in_entry = False
                
            if in_entry and line.strip().startswith("Icon="):
                new_lines.append(f"Icon={slug}")
                replaced_icon = True
            else:
                new_lines.append(line)

        if not replaced_icon:
            # If no Icon= found in [Desktop Entry], add it
            final_lines = []
            for line in new_lines:
                final_lines.append(line)
                if line.strip().startswith("[Desktop Entry]"):
                    final_lines.append(f"Icon={slug}")
            new_lines = final_lines

        user_desktop_path.parent.mkdir(parents=True, exist_ok=True)
        user_desktop_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")

        # 4. Refresh system caches
        refresh_system_caches()
        return True, slug
    except Exception as e:
        return False, str(e)


def revert_app_icon(app: AppInfo) -> tuple[bool, str]:
    """
    Reverts an application back to its original unpatched icon.
    """
    try:
        history = load_history()
        record = history.get(app.id)
        
        user_desktop_path = USER_APPLICATIONS_DIR / app.id

        if record:
            orig_icon = record.get("original_icon")
            created_override = record.get("created_user_override", False)
            patched_slug = record.get("patched_slug")

            # If we created a user override over /usr/share/applications, remove the user override
            if created_override and user_desktop_path.exists():
                user_desktop_path.unlink()
            elif user_desktop_path.exists() and orig_icon:
                # Restore original Icon= line
                content = user_desktop_path.read_text(encoding="utf-8", errors="ignore")
                new_lines = []
                for line in content.splitlines():
                    if line.strip().startswith("Icon="):
                        new_lines.append(f"Icon={orig_icon}")
                    else:
                        new_lines.append(line)
                user_desktop_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")

            # Remove generated squircle icon files
            if patched_slug:
                for target_path in [
                    WHITESUR_SCALABLE_DIR / f"{patched_slug}.svg",
                    HICOLOR_SCALABLE_DIR / f"{patched_slug}.svg",
                    VITRUM_ICONOS_DIR / f"{patched_slug}.svg",
                    HICOLOR_512_DIR / f"{patched_slug}.png"
                ]:
                    if target_path.exists():
                        try:
                            target_path.unlink()
                        except Exception:
                            pass

            # Remove from history
            del history[app.id]
            save_history(history)

            # Refresh system caches
            refresh_system_caches()
            return True, "Ícono restaurado correctamente."
        else:
            return False, "No se encontró registro de respaldo para esta aplicación."
    except Exception as e:
        return False, str(e)
