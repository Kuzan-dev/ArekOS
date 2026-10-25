"""
Constants and paths for Vitrum Window Patcher.
"""

from pathlib import Path

HOME = Path.home()
VITRUM_KDE_DIR = HOME / "vitrum-kde"
ZEN_USERCHROME_SRC = VITRUM_KDE_DIR / "integracion/zen-userChrome.css"
STEAM_VITRUM_CSS = VITRUM_KDE_DIR / "integracion/steam-vitrum.css"
KWINRULESRC_PATH = HOME / ".config/kwinrulesrc"

# Flatpak and Native paths
ZEN_FLATPAK_DIR = HOME / ".var/app/app.zen_browser.zen/.zen"
ZEN_NATIVE_DIR = HOME / ".zen"

STEAM_NATIVE_DIR = HOME / ".local/share/Steam"
STEAM_FLATPAK_DIR = HOME / ".var/app/com.valvesoftware.Steam/data/Steam"

CHROME_FLATPAK_PREFS = HOME / ".var/app/com.google.Chrome/config/google-chrome/Default/Preferences"
CHROME_NATIVE_PREFS = HOME / ".config/google-chrome/Default/Preferences"

VSCODE_NATIVE_SETTINGS = HOME / ".config/Code/User/settings.json"
VSCODE_FLATPAK_SETTINGS = HOME / ".var/app/com.visualstudio.code/config/Code/User/settings.json"
VSCODIUM_SETTINGS = HOME / ".config/VSCodium/User/settings.json"
