#!/usr/bin/env python3
"""Parches de Vitrum sobre Darkly (kstyle/): texto desactivado de los menús como en macOS, esquinas de los
menús como en macOS Tahoe (4 px más redondeadas que el resto de controles, también en el desenfoque y la sombra)
botones en píldora como en Tahoe y, en Dolphin, la barra lateral opaca con el tono de la del Finder.

Darkly pinta las entradas desactivadas con el grupo Disabled del esquema, que KDE calcula difuminando el
texto hacia el fondo OPACO de la vista (blanco en el modo claro). Con los menús translúcidos (MenuOpacity 55)
el fondo real queda mucho más oscuro (~175 sobre un fondo de escritorio oscuro) y el texto (~170) desaparecía
(p. ej. "Pegar" y "Deshacer" en el menú del escritorio en modo claro). macOS usa el color normal del texto al
25-30 % de opacidad (disabledControlTextColor), que se adapta a lo que haya detrás del menú.

Uso: parchear-menus.py <ruta a darklystyle.cpp>   (idempotente)
"""
import os
import sys

p = sys.argv[1]
d = os.path.dirname(p)


def parchear(ruta, marca, cambios):
    """Aplica [(viejo, nuevo)] a un archivo si no tiene ya la marca (idempotente)."""
    t = open(ruta).read()
    if marca in t:
        return
    for viejo, nuevo in cambios:
        assert t.count(viejo) == 1, f"no se encontró en {os.path.basename(ruta)}: {viejo[:60]}"
        t = t.replace(viejo, nuevo)
    open(ruta, "w").write(t)


# Menús de Tahoe: radio de CornerRadius + 4 en el marco, en la región de desenfoque y en la sombra
TAHOE = "// Vitrum: menús de Tahoe"
parchear(os.path.join(d, "darklyhelper.cpp"), TAHOE, [(
    """        QRectF frameRect(rect);
        qreal radius(frameRadius(PenWidth::NoPen));

        painter->setPen(Qt::NoPen);""",
    """        QRectF frameRect(rect);
        qreal radius(frameRadius(PenWidth::NoPen) + 4); // Vitrum: menús de Tahoe, 4 px más redondeados

        painter->setPen(Qt::NoPen);""")])
parchear(os.path.join(d, "darklyblurhelper.cpp"), TAHOE, [(
    """        return roundedRegion(rect, StyleConfigData::cornerRadius() + 1, true, true, true, true);""",
    """        return roundedRegion(rect, StyleConfigData::cornerRadius() + 5, true, true, true, true); // Vitrum: menús de Tahoe""")])
parchear(os.path.join(d, "darklyshadowhelper.cpp"), TAHOE, [(
    """    const qreal frameRadius = _helper.frameRadius();

    BoxShadowRenderer shadowRenderer;""",
    """    const qreal frameRadius = _helper.frameRadius() + 4; // Vitrum: menús de Tahoe (las sombras de Darkly son de menús)

    BoxShadowRenderer shadowRenderer;""")])

# Botones de Tahoe: en píldora (radio de medio alto), también el brillo superior del modo oscuro. Lo usan los
# botones normales, los desplegables y la parte del menú de los botones con menú
PILDORA = "// Vitrum: botones en píldora"
parchear(os.path.join(d, "darklyhelper.cpp"), PILDORA, [(
    """    QRectF frameRect(rect.adjusted(Metrics::Frame_FrameWidth, Metrics::Frame_FrameWidth, -Metrics::Frame_FrameWidth, -Metrics::Frame_FrameWidth));
    qreal radius(frameRadius() - qreal(Metrics::Frame_FrameWidth));

    if (sunken) {""",
    """    QRectF frameRect(rect.adjusted(Metrics::Frame_FrameWidth, Metrics::Frame_FrameWidth, -Metrics::Frame_FrameWidth, -Metrics::Frame_FrameWidth));
    qreal radius(qMin(frameRect.width(), frameRect.height()) / 2); // Vitrum: botones en píldora, como en macOS Tahoe

    if (sunken) {"""), (
    """    if (isDarkTheme(palette) && enabled)
        topHighlight(painter, frameRect, StyleConfigData::cornerRadius());

    // pressed animation""",
    """    if (isDarkTheme(palette) && enabled)
        topHighlight(painter, frameRect, qRound(radius));

    // pressed animation""")])

# Dolphin con la barra lateral opaca (DolphinSidebarOpacity 100, «Permitir que el fondo tiña las ventanas»
# desactivado): un tono propio para separarla del contenido, como el Finder de Tahoe (#1A1C23 en oscuro, medido
# en las capturas; un gris azulado equivalente en claro)
OPACA = "// Vitrum: barra lateral opaca de Dolphin"
parchear(p, OPACA, [(
    """        } else {
            if (_isDolphin && dockWidget->inherits("DolphinDockWidget") && _translucentWidgets.contains(dockWidget->window())) {""",
    """        } else {
            // Vitrum: barra lateral opaca de Dolphin, con el tono de la del Finder de Tahoe
            if (_isDolphin && dockWidget->inherits("DolphinDockWidget") && StyleConfigData::dolphinSidebarOpacity() >= 100) {
                painter.fillRect(rect, _helper->isDarkTheme(palette) ? QColor(26, 28, 35) : QColor(236, 237, 242));
            }
            if (_isDolphin && dockWidget->inherits("DolphinDockWidget") && _translucentWidgets.contains(dockWidget->window())) {""")])

s = open(p).read()
MARCA = "// Vitrum: texto desactivado"
if MARCA in s:
    print("ya parcheado")
    sys.exit(0)

old = """        // locate accelerator and render
        const int tabPosition(text.indexOf(QLatin1Char('\\t')));
        if (tabPosition >= 0) {
            // add a bit of transparency
            QColor c(palette.color(role));
            c.setAlpha(100);
            QPalette p;
            p.setColor(role, c);

            const int textFlags(Qt::AlignVCenter | Qt::AlignRight);
            QString accelerator(text.mid(tabPosition + 1));
            text = text.left(tabPosition);
            drawItemText(painter, textRect, textFlags, p, enabled, accelerator, role);
        }

        // render text
        const int textFlags(Qt::AlignVCenter | (reverseLayout ? Qt::AlignRight : Qt::AlignLeft) | _mnemonics->textFlags());
        textRect = option->fontMetrics.boundingRect(textRect, textFlags, text);
        drawItemText(painter, textRect, textFlags, palette, enabled, text, role);
"""
new = """        // Vitrum: texto desactivado como en macOS (color normal al 30 %), legible sobre el fondo translúcido
        QPalette textPalette(palette);
        if (!enabled) {
            QColor disabledColor(palette.color(QPalette::Active, role));
            disabledColor.setAlphaF(0.30);
            textPalette.setColor(role, disabledColor); // todos los grupos: no depender del grupo actual
        }

        // locate accelerator and render
        const int tabPosition(text.indexOf(QLatin1Char('\\t')));
        if (tabPosition >= 0) {
            // add a bit of transparency
            QColor c(textPalette.color(role));
            if (enabled)
                c.setAlpha(100);
            QPalette p;
            p.setColor(role, c);

            const int textFlags(Qt::AlignVCenter | Qt::AlignRight);
            QString accelerator(text.mid(tabPosition + 1));
            text = text.left(tabPosition);
            drawItemText(painter, textRect, textFlags, p, enabled, accelerator, role);
        }

        // render text
        const int textFlags(Qt::AlignVCenter | (reverseLayout ? Qt::AlignRight : Qt::AlignLeft) | _mnemonics->textFlags());
        textRect = option->fontMetrics.boundingRect(textRect, textFlags, text);
        drawItemText(painter, textRect, textFlags, textPalette, enabled, text, role);
"""
assert s.count(old) == 1, "no se encontró el bloque de texto de drawMenuItemControl"
s = s.replace(old, new)
open(p, "w").write(s)
print("parcheado")

