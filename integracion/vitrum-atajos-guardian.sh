# Vitrum: atajos globales de macOS (se ejecuta al iniciar sesión, antes que KWin).
# kglobalaccel vive dentro de KWin: si se editan los atajos con la sesión abierta, KWin conserva los suyos en
# memoria y, al registrarse Launchpad con «Meta», gana el lanzador de Plasma que ya la tenía (Launchpad queda
# vacío). Aquí se fijan antes de que KWin arranque, así que siempre se cargan bien.
kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate application launcher" "Alt+F1,Meta"$'\t'"Alt+F1,Activar el lanzador de aplicaciones"
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.krunner.desktop --key _launch "Alt+F2"$'\t'"Search"
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.vitrum.launchpad.desktop --key _launch "Meta"
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.vitrum.spotlight-atajo.desktop --key _launch "Meta+Space"$'\t'"Alt+Space"$'\t'"Meta+S"
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.vitrum.vistarapida.desktop --key _launch "Meta+Y"
