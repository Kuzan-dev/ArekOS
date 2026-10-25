"""
KWin Decoration Rules Manager for Vitrum Window Patcher.
Enables native Vitrum macOS semáforos and 10px rounded corners on any Electron, game, or custom app.
"""

import os
import subprocess
import configparser
from pathlib import Path
from typing import Dict, List, Tuple, Optional

from ..constants import KWINRULESRC_PATH


COMMON_APPS = [
    {
        "id": "heroic",
        "name": "Heroic Games Launcher",
        "wmclass": "heroic",
        "description": "Fuerza barra de título y semáforos en la interfaz de Heroic Games"
    },
    {
        "id": "stremio",
        "name": "Stremio",
        "wmclass": "stremio",
        "description": "Semáforos nativos y esquinas redondeadas en el reproductor Stremio"
    },
    {
        "id": "spotify",
        "name": "Spotify",
        "wmclass": "spotify",
        "description": "Fuerza semáforos nativos en la barra superior de Spotify"
    },
    {
        "id": "discord",
        "name": "Discord / Vesktop",
        "wmclass": "discord",
        "description": "Decoración Vitrum y controles macOS en la ventana de Discord"
    },
    {
        "id": "hydra",
        "name": "Hydra Launcher",
        "wmclass": "hydralauncher",
        "description": "Semáforos macOS en Hydra Launcher"
    },
    {
        "id": "boilr",
        "name": "BoilR",
        "wmclass": "io.github.philipk.boilr",
        "description": "Controles y sombra nativa de Vitrum en BoilR"
    },
    {
        "id": "antimicrox",
        "name": "AntiMicroX",
        "wmclass": "antimicrox",
        "description": "Bordes de 10px y semáforos en el asignador de mando AntiMicroX"
    },
    {
        "id": "openrgb",
        "name": "OpenRGB",
        "wmclass": "openrgb",
        "description": "Decoración nativa con semáforos en OpenRGB"
    },
    {
        "id": "obsidian",
        "name": "Obsidian",
        "wmclass": "obsidian",
        "description": "Fuerza marco del sistema y semáforos en notas de Obsidian"
    }
]


def load_kwinrules() -> configparser.ConfigParser:
    cp = configparser.ConfigParser(interpolation=None)
    if KWINRULESRC_PATH.exists():
        cp.read(str(KWINRULESRC_PATH), encoding="utf-8")
    if "General" not in cp:
        cp["General"] = {"count": "0", "rules": ""}
    return cp


def save_kwinrules(cp: configparser.ConfigParser):
    KWINRULESRC_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(KWINRULESRC_PATH, "w", encoding="utf-8") as f:
        cp.write(f)
    # Notify KWin live
    subprocess.run(["qdbus-qt6", "org.kde.KWin", "/KWin", "reconfigure"], capture_output=True)


def is_rule_active(rule_id: str) -> bool:
    cp = load_kwinrules()
    section_name = f"{rule_id}-vitrum-rule"
    rules_list = [r.strip() for r in cp.get("General", "rules", fallback="").split(",") if r.strip()]
    return section_name in cp and section_name in rules_list


def add_kwin_decoration_rule(rule_id: str, name: str, wmclass: str) -> Tuple[bool, str]:
    try:
        cp = load_kwinrules()
        section_name = f"{rule_id}-vitrum-rule"
        
        rules_list = [r.strip() for r in cp.get("General", "rules", fallback="").split(",") if r.strip()]
        if section_name not in rules_list:
            rules_list.append(section_name)

        cp["General"]["rules"] = ",".join(rules_list)
        cp["General"]["count"] = str(len(rules_list))

        cp[section_name] = {
            "Description": f"{name} Vitrum Decoration",
            "noborder": "false",
            "noborderrule": "2",
            "types": "1",
            "wmclass": wmclass,
            "wmclasscomplete": "false",
            "wmclassmatch": "1"
        }

        save_kwinrules(cp)
        return True, f"Regla de decoración aplicada para {name}."
    except Exception as e:
        return False, str(e)


def remove_kwin_decoration_rule(rule_id: str) -> Tuple[bool, str]:
    try:
        cp = load_kwinrules()
        section_name = f"{rule_id}-vitrum-rule"

        rules_list = [r.strip() for r in cp.get("General", "rules", fallback="").split(",") if r.strip()]
        rules_list = [r for r in rules_list if r != section_name]

        cp["General"]["rules"] = ",".join(rules_list)
        cp["General"]["count"] = str(len(rules_list))

        if section_name in cp:
            cp.remove_section(section_name)

        save_kwinrules(cp)
        return True, f"Regla de decoración eliminada."
    except Exception as e:
        return False, str(e)
