"""
Constants and geometry settings for Vitrum Icon Patcher.
Based on the authentic WhiteSur macOS squircle specification:
- Canvas: 64x64
- Drop shadow: width=60.882 height=62.001 x=1.559 y=1.999
- Squircle rect: width=56 height=56 x=4 y=4 rx=13 ry=13
"""

import os
from pathlib import Path

# Load authentic WhiteSur drop shadow
SHADOW_FILE = Path(__file__).parent / "shadow.txt"
if SHADOW_FILE.exists():
    SHADOW_BASE64 = SHADOW_FILE.read_text().strip()
else:
    SHADOW_BASE64 = ""

# Standard System & User Directories
HOME = Path.home()
USER_APPLICATIONS_DIR = HOME / ".local/share/applications"
USER_ICONS_DIR = HOME / ".local/share/icons"
WHITESUR_SCALABLE_DIR = USER_ICONS_DIR / "WhiteSur/apps/scalable"
HICOLOR_SCALABLE_DIR = USER_ICONS_DIR / "hicolor/scalable/apps"
HICOLOR_512_DIR = USER_ICONS_DIR / "hicolor/512x512/apps"
HICOLOR_256_DIR = USER_ICONS_DIR / "hicolor/256x256/apps"
VITRUM_ICONOS_DIR = HOME / "vitrum-kde/iconos-apps"

CONFIG_DIR = HOME / ".config/vitrum-icon-patcher"
CONFIG_FILE = CONFIG_DIR / "config.json"
BACKUP_FILE = CONFIG_DIR / "patch_history.json"

SYSTEM_DESKTOP_DIRS = [
    str(USER_APPLICATIONS_DIR),
    str(HOME / ".local/share/flatpak/exports/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    "/usr/share/applications",
]

# Color Palettes Presets (top_color, bottom_color, name)
PRESET_PALETTES = [
    ("auto", "auto", "🎨 Automático (Extraer del logo)"),
    ("#1f2336", "#0a0a0f", "🌌 Max / Noche Oscura"),
    ("#00a8b5", "#07263b", "🌊 Disney+ / Océano Profundo"),
    ("#ff7b25", "#e24c00", "🟠 Crunchyroll / Mandarina"),
    ("#1f2d45", "#0e1626", "🏹 Quiver / Azul Noche"),
    ("#282c34", "#181a1f", "💻 Slate / Gris Apple"),
    ("#1db954", "#121212", "🟢 Spotify / Esmeralda"),
    ("#7289da", "#23272a", "🟣 Discord / Índigo"),
    ("#ff334b", "#b30018", "🔴 YouTube / Rojo Carmín"),
    ("#14213d", "#000000", "🕶️ Vitrum Dark Glass"),
    ("#3a7bd5", "#3a6073", "🔷 Mar Azul"),
    ("#8e2de2", "#4a00e0", "💜 Deep Purple"),
]
