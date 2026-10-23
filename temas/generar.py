#!/usr/bin/env python3
"""Temas globales Vitrum Claro / Vitrum Oscuro y fondo "Vitrum" (claro/oscuro automático).

Un tema global (look-and-feel) cambia de una vez esquema de color, iconos, estilo de las apps,
decoración, tema de Plasma y cursor; Plasma lo aplica en vivo y puede alternarlos solo según la hora.
"""
import json, os, shutil

HOME = os.path.expanduser("~")
LNF = f"{HOME}/.local/share/plasma/look-and-feel"
BASE = f"{LNF}/com.github.vinceliuice.MacTahoe-Light"   # para las vistas previas y la pantalla de bienvenida
WALL = f"{HOME}/.local/share/wallpapers"

for pid, name, dark in (("org.vitrum.claro", "Vitrum Claro", False), ("org.vitrum.oscuro", "Vitrum Oscuro", True)):
    d = f"{LNF}/{pid}"
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(f"{d}/contents", exist_ok=True)
    for sub in ("previews", "splash"):
        if os.path.isdir(f"{BASE}/contents/{sub}"):
            shutil.copytree(f"{BASE}/contents/{sub}", f"{d}/contents/{sub}")
    os.makedirs(f"{d}/contents/logout", exist_ok=True)
    shutil.copy(os.path.join(os.path.dirname(os.path.abspath(__file__)), "logout/Logout.qml"), f"{d}/contents/logout/Logout.qml")
    json.dump({
        "KPackageStructure": "Plasma/LookAndFeel",
        "KPlugin": {"Id": pid, "Name": name, "Description": "Estilo macOS Sequoia para Plasma", "Authors": [{"Name": "Vitrum"}],
                    "License": "GPL-3.0", "Version": "1.0"},
        "X-Plasma-APIVersion": "2",
    }, open(f"{d}/metadata.json", "w"), indent=4, ensure_ascii=False)
    with open(f"{d}/contents/defaults", "w") as f:
        f.write(f"""[kdeglobals][General]
ColorScheme={"VitrumDark" if dark else "VitrumLight"}

[kdeglobals][Icons]
Theme={"WhiteSur-dark" if dark else "WhiteSur-light"}

[kdeglobals][KDE]
widgetStyle=Klassy

[kcminputrc][Mouse]
cursorTheme=WhiteSur-cursors

[kwinrc][org.kde.kdecoration2]
library=org.kde.klassy
theme=Klassy
ButtonsOnLeft=XIA
ButtonsOnRight=

[plasmarc][Theme]
name=Vitrum

[kwinrc][WindowSwitcher]
LayoutName=org.kde.breeze.desktop

[kwinrc][DesktopSwitcher]
LayoutName=org.kde.breeze.desktop
""")

# Fondo con variante clara y oscura: Plasma elige images/ o images_dark/ según el esquema
w = f"{WALL}/Vitrum"
shutil.rmtree(w, ignore_errors=True)
os.makedirs(f"{w}/contents", exist_ok=True)
shutil.copytree(f"{WALL}/WhiteSur-light/contents/images", f"{w}/contents/images")
shutil.copytree(f"{WALL}/WhiteSur-dark/contents/images", f"{w}/contents/images_dark")
json.dump({"KPackageStructure": "Plasma/Wallpaper", "KPlugin": {"Id": "Vitrum", "Name": "Vitrum (claro y oscuro)", "License": "CC-BY-SA-4.0",
           "Authors": [{"Name": "Vince Liuice (WhiteSur)"}]}}, open(f"{w}/metadata.json", "w"), indent=4)
print("temas globales y fondo Vitrum generados")
