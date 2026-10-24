#!/usr/bin/env python3
"""Convierte el código de plasma-login-manager en el greeter de Vitrum (vitrum-login-greeter).
Uso: parchear.py <raíz de plasma-login-manager>
Cambia solo la interfaz (Main.qml, la de login/ de Vitrum) y hace que el programa termine con error si esa
interfaz no carga: así el lanzador (vitrum-login-lanzador) pasa a la pantalla original de Fedora en vez de
dejar una pantalla vacía. La autenticación y los modelos son los de Plasma Login, sin tocar."""
import os, shutil, sys
src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
g = os.path.join(src, "src/frontend/greeter")
shutil.copy(os.path.join(here, "Main.qml"), os.path.join(g, "qml/Main.qml"))
p = os.path.join(g, "main.cpp")
s = open(p, encoding="utf-8").read()
old = '        window->setSource(QUrl("qrc:/qt/qml/org/kde/plasma/login/Main.qml"));\n'
if old not in s:
    sys.exit("parchear: main.cpp ha cambiado")
s = s.replace(old, old + '''        if (window->status() == QQmlComponent::Error || !window->rootObject()) {
            qCritical() << "vitrum-login-greeter: la interfaz no cargó" << window->errors();
            std::exit(3); // el lanzador usará la pantalla original de Fedora
        }
''', 1)
s = s.replace("#include <QScreen>\n", "#include <QScreen>\n#include <QQmlComponent>\n#include <cstdlib>\n", 1)
open(p, "w", encoding="utf-8").write(s)
# Esc: en macOS cancela la elección de usuario; Plasma Login además apagaba las pantallas (DPMS), lo que dejaba
# la pantalla en negro al cancelar. Se conserva solo la señal.
p = os.path.join(g, "greetereventfilter.cpp")
s = open(p, encoding="utf-8").read()
a = s.find("            // Esc -> turn off screens")
b = s.find("            Q_EMIT escapeKeyPressed();")
if a < 0 or b < 0:
    sys.exit("parchear: greetereventfilter.cpp ha cambiado")
s = s[:a] + s[b:]
open(p, "w", encoding="utf-8").write(s)
print("greeter de Vitrum preparado en", src)
