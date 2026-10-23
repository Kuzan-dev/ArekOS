#!/usr/bin/env python3
"""Genera el tema de Plasma "Vitrum" (estilo macOS Sequoia).

Parte de MacTahoe-Light para los widgets y sustituye las superficies principales por SVG generados:
barra de menús (plana, translúcida), dock (flotante, redondeado), menús emergentes y tooltips.
Los colores salen del esquema activo (ColorScheme-Background/Text), así que un único tema sirve
para claro y oscuro y Plasma lo actualiza en vivo al cambiar de esquema.
"""
import os, shutil, sys

HOME = os.path.expanduser("~")
SRC = f"{HOME}/.local/share/plasma/desktoptheme/MacTahoe-Light"
DST = f"{HOME}/.local/share/plasma/desktoptheme/Vitrum"
# Variantes: Plasma solo redibuja la barra y los menús al cambiar de tema, no al cambiar el esquema,
# así que hay un tema por modo, cada uno con los colores de su esquema (Vitrum Claro / Oscuro).
VARIANTS = (("Vitrum", "VitrumLight", "Vitrum Claro", "#F6F6F6"), ("Vitrum-Oscuro", "VitrumDark", "Vitrum Oscuro", "#1E1E1E"))
OUTLINE = 0.45  # opacidad del contorno oscuro exterior (lo fija cada variante)
BG = "#F6F6F6"   # color de las superficies (barra, dock, menús); lo fija cada variante

STYLE = """<style type="text/css" id="current-color-scheme">
.ColorScheme-Background { color:#f6f6f6; }
.ColorScheme-Text { color:#1d1d1f; }
</style>"""


class Frame:
    """Construye las 9 piezas (+máscara y sombra) de un marco de Plasma con esquinas redondeadas."""

    def __init__(self):
        self.parts = []
        self.x = 0  # cada pieza en su propia columna para que no se solapen

    def _place(self, w):
        x = self.x
        self.x += w + 4
        return x

    def frame(self, prefix, r, alpha, edge_alpha, margins, flat=False, mask=True, shadow=0, fill_color=None):
        p = f"{prefix}-" if prefix else ""
        r = max(r, 1)
        rr = 0 if flat else r
        def piece(name, w, h, body):
            x = self._place(w)
            self.parts.append(f'<g id="{p}{name}" transform="translate({x},0)">'
                              f'<rect width="{w}" height="{h}" fill="none"/>{body}</g>')
        fill = f'fill="{fill_color or BG}" fill-opacity="{alpha}"'
        edge = f'fill="#ffffff" fill-opacity="{edge_alpha}"'
        mfill = 'fill="#000000"'
        def corner(kind, f, e=None):
            # cuarto de círculo de radio rr dentro de una caja r×r, orientado según la esquina
            if rr == 0:
                body = f'<rect width="{r}" height="{r}" {f}/>'
            else:
                body = f'<path d="M0,{r} A{r},{r} 0 0 1 {r},0 L{r},{r} Z" {f}/>'
                if e:
                    body += (f'<path fill-rule="evenodd" d="M0,{r} A{r},{r} 0 0 1 {r},0 L{r},1 '
                             f'A{r-1},{r-1} 0 0 0 1,{r} Z" {e}/>')
            rot = {"topleft": "", "topright": f'transform="translate({r},0) scale(-1,1)"',
                   "bottomleft": f'transform="translate(0,{r}) scale(1,-1)"',
                   "bottomright": f'transform="translate({r},{r}) scale(-1,-1)"'}[kind]
            return f'<g {rot}>{body}</g>'
        for kind in ("topleft", "topright", "bottomleft", "bottomright"):
            piece(kind, r, r, corner(kind, fill, None if flat else edge))
        e1 = "" if flat else f'<rect width="10" height="1" {edge}/>'
        piece("top", 10, r, f'<rect width="10" height="{r}" {fill}/>' + e1)
        piece("bottom", 10, r, f'<rect width="10" height="{r}" {fill}/>' + ("" if flat else f'<rect y="{r-1}" width="10" height="1" {edge}/>'))
        piece("left", r, 10, f'<rect width="{r}" height="10" {fill}/>' + ("" if flat else f'<rect width="1" height="10" {edge}/>'))
        piece("right", r, 10, f'<rect width="{r}" height="10" {fill}/>' + ("" if flat else f'<rect x="{r-1}" width="1" height="10" {edge}/>'))
        piece("center", 10, 10, f'<rect width="10" height="10" {fill}/>')
        t, b, l, rt = margins
        for name, w, h in (("hint-top-margin", 1, t), ("hint-bottom-margin", 1, b), ("hint-left-margin", l, 1), ("hint-right-margin", rt, 1)):
            piece(name, w, h, f'<rect width="{w}" height="{h}" fill="#ff0000" fill-opacity="0"/>')
        if mask:
            # máscara (zona que KWin desenfoca): misma forma, opaca
            mp = Frame()
            mp.x = self.x
            mp.parts = []
            mp_prefix = f"{p}mask" if p else "mask"
            for kind in ("topleft", "topright", "bottomleft", "bottomright"):
                x = self._place(r)
                self.parts.append(f'<g id="{mp_prefix}-{kind}" transform="translate({x},0)"><rect width="{r}" height="{r}" fill="none"/>{corner(kind, mfill)}</g>')
            for name, w, h in (("top", 10, r), ("bottom", 10, r), ("left", r, 10), ("right", r, 10), ("center", 10, 10)):
                x = self._place(w)
                self.parts.append(f'<g id="{mp_prefix}-{name}" transform="translate({x},0)"><rect width="{w}" height="{h}" {mfill}/></g>')
        if shadow:
            # sombra suave: anillos concéntricos con opacidad decreciente (QtSvg no admite filtros)
            s = shadow
            sp = f"{p}shadow" if p else "shadow"
            def ring_body(kind, w, h):
                out = []
                steps = s
                for i in range(steps):
                    a = 0.10 * (1 - i / steps) ** 2
                    if i == 0:
                        a = OUTLINE   # contorno oscuro nítido de 1 px, como el de los paneles de macOS
                    out.append((i, a))
                return out
            size = s + r
            for kind in ("topleft", "topright", "bottomleft", "bottomright"):
                x = self._place(size)
                # cuartos de anillo rellenos: QtSvg no soporta clipPath e ignora stroke-opacity
                def ring(i, a):
                    r1, r2 = r + i, r + i + 1
                    return (f'<path fill-rule="evenodd" fill="#000" fill-opacity="{a:.4f}" d="'
                            f'M{size - r2},{size} A{r2},{r2} 0 0 1 {size},{size - r2} L{size},{size - r1} '
                            f'A{r1},{r1} 0 0 0 {size - r1},{size} Z"/>')
                rings = "".join(ring(i, a) for i, a in ring_body(kind, size, size))
                rot = {"topleft": "", "topright": f'transform="translate({size},0) scale(-1,1)"',
                       "bottomleft": f'transform="translate(0,{size}) scale(1,-1)"',
                       "bottomright": f'transform="translate({size},{size}) scale(-1,-1)"'}[kind]
                self.parts.append(f'<g id="{sp}-{kind}" transform="translate({x},0)"><rect width="{size}" height="{size}" fill="none"/><g {rot}>{rings}</g></g>')
            for name, w, h, horiz in (("top", 10, s, True), ("bottom", 10, s, True), ("left", s, 10, False), ("right", s, 10, False)):
                x = self._place(w)
                lines = []
                for i, a in ring_body(name, w, h):
                    if name == "top": lines.append(f'<rect y="{s-1-i}" width="10" height="1" fill="#000" fill-opacity="{a:.4f}"/>')
                    if name == "bottom": lines.append(f'<rect y="{i}" width="10" height="1" fill="#000" fill-opacity="{a:.4f}"/>')
                    if name == "left": lines.append(f'<rect x="{s-1-i}" width="1" height="10" fill="#000" fill-opacity="{a:.4f}"/>')
                    if name == "right": lines.append(f'<rect x="{i}" width="1" height="10" fill="#000" fill-opacity="{a:.4f}"/>')
                self.parts.append(f'<g id="{sp}-{name}" transform="translate({x},0)"><rect width="{w}" height="{h}" fill="none"/>{"".join(lines)}</g>')
            for name in ("top", "bottom", "left", "right"):
                w, h = (1, s) if name in ("top", "bottom") else (s, 1)
                x = self._place(w)
                self.parts.append(f'<g id="{sp}-hint-{name}-margin" transform="translate({x},0)"><rect width="{w}" height="{h}" fill="none"/></g>')

    def svg(self):
        return ('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" '
                f'width="{self.x}" height="200">\n{STYLE}\n' + "\n".join(self.parts) + "\n</svg>\n")


def write(DST, path, frame):
    full = os.path.join(DST, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    for ext in (".svgz", ".svg"):
        if os.path.exists(full + ext):
            os.remove(full + ext)
    with open(full + ".svg", "w") as f:
        f.write(frame.svg())


def build(DST, scheme, title):
    if not os.path.isdir(SRC):
        sys.exit("falta MacTahoe-Light")
    shutil.rmtree(DST, ignore_errors=True)
    shutil.copytree(SRC, DST)
    shutil.rmtree(os.path.join(DST, "solid"), ignore_errors=True)   # sin variantes opacas: siempre translúcido

    # Barra de menús (panel arriba, pegado): plana, sin borde. Dock (flotante): redondeado con borde de luz.
    panel = Frame()
    # macOS deja pasar mucho color del fondo por la barra (≈40 % de blanco sobre el desenfoque)
    panel.frame("north", 1, 0.38 if BG == "#F6F6F6" else 0.22, 0, (2, 2, 6, 6), flat=True)
    # sin sombra: Plasma usa la sombra del marco genérico también bajo la barra de menús, y en macOS la barra no
    # tiene sombra ni línea inferior (el dock es de vitrum-shell y dibuja la suya)
    panel.frame("", 16, 0.42, 0.30, (6, 6, 8, 8))
    panel.frame("south", 16, 0.42, 0.30, (6, 6, 8, 8))
    for side in ("west", "east"):
        panel.frame(side, 16, 0.42, 0.30, (8, 8, 6, 6))
    write(DST, "widgets/panel-background", panel)

    dialog = Frame()
    # medido en macOS con el mismo fondo: menús y paneles ≈50 % de material sobre el desenfoque
    dialog.frame("", 10, 0.50 if BG == "#F6F6F6" else 0.45, 0.0 if BG == "#F6F6F6" else 0.20, (8, 8, 8, 8), shadow=12)
    write(DST, "dialogs/background", dialog)

    # Selección de iconos (escritorio y listas de Plasma): como en macOS, un recuadro oscuro translúcido con filo
    # claro, visible sobre cualquier fondo (el de MacTahoe era casi transparente y no se veía en fondos cargados)
    item = Frame()
    for name, a, e in (("normal", 0.0, 0.0), ("hover", 0.14, 0.18), ("selected", 0.30, 0.38), ("selected+hover", 0.34, 0.42)):
        item.frame(name, 6, a, e, (4, 4, 4, 4), mask=False, fill_color="#000000")
    write(DST, "widgets/viewitem", item)

    tip = Frame()
    tip.frame("", 6, 0.86, 0.25, (3, 3, 8, 8), shadow=6)
    write(DST, "widgets/tooltip", tip)

    meta = f"{DST}/metadata.json"
    import json
    m = json.load(open(meta))
    m["KPlugin"].update({"Id": os.path.basename(DST), "Name": title, "Description": "Vitrum: estilo macOS Sequoia", "Authors": [{"Name": "Vitrum"}]})
    json.dump(m, open(meta, "w"), indent=4, ensure_ascii=False)
    if os.path.exists(f"{DST}/metadata.desktop"):
        os.remove(f"{DST}/metadata.desktop")
    shutil.copy(f"{HOME}/.local/share/color-schemes/{scheme}.colors", f"{DST}/colors")
    with open(f"{DST}/plasmarc", "w") as f:
        f.write("""[Wallpaper]
defaultWallpaperTheme=WhiteSur-light
defaultFileSuffix=.jpg
defaultWidth=3840
defaultHeight=2160

[ContrastEffect]
enabled=true
contrast=1.0
intensity=1.0
saturation=1.5

[AdaptiveTransparency]
enabled=false
""")
    print("tema generado:", DST)


for name, scheme, title, bg in VARIANTS:
    BG = bg
    OUTLINE = 0.22 if bg == "#F6F6F6" else 0.55
    build(f"{HOME}/.local/share/plasma/desktoptheme/{name}", scheme, title)
