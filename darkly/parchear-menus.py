#!/usr/bin/env python3
"""Parche de Vitrum sobre Darkly (kstyle/darklystyle.cpp): texto desactivado de los menús como en macOS.

Darkly pinta las entradas desactivadas con el grupo Disabled del esquema, que KDE calcula difuminando el
texto hacia el fondo OPACO de la vista (blanco en el modo claro). Con los menús translúcidos (MenuOpacity 55)
el fondo real queda mucho más oscuro (~175 sobre un fondo de escritorio oscuro) y el texto (~170) desaparecía
(p. ej. "Pegar" y "Deshacer" en el menú del escritorio en modo claro). macOS usa el color normal del texto al
25-30 % de opacidad (disabledControlTextColor), que se adapta a lo que haya detrás del menú.

Uso: parchear-menus.py <ruta a darklystyle.cpp>   (idempotente)
"""
import sys

p = sys.argv[1]
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
