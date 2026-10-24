#!/bin/bash
# Instala la pantalla de bloqueo de Vitrum para el usuario actual, sin tocar el sistema.
# El bloqueador busca su interfaz en el paquete de shell «org.kde.plasma.desktop»: se crea una copia local
# hecha de enlaces a la del sistema (así sigue las actualizaciones de Plasma) en la que solo la carpeta
# lockscreen tiene archivos propios. Para volver a la de KDE: vitrum-bloqueo --quitar
set -eu
sis=/usr/share/plasma/shells/org.kde.plasma.desktop
loc=~/.local/share/plasma/shells/org.kde.plasma.desktop
src=${1:-$(dirname "$(readlink -f "$0")")}
if [ "${1:-}" = --quitar ]; then rm -rf "$loc"; echo "pantalla de bloqueo de KDE restaurada"; exit 0; fi
rm -rf "$loc"; mkdir -p "$loc/contents/lockscreen"
ln -s "$sis/metadata.json" "$loc/metadata.json"
for d in "$sis"/contents/*; do
    [ "$(basename "$d")" = lockscreen ] || ln -s "$d" "$loc/contents/$(basename "$d")"
done
for f in "$sis"/contents/lockscreen/*; do ln -s "$f" "$loc/contents/lockscreen/$(basename "$f")"; done
for f in LockScreen.qml LockScreenUi.qml; do rm -f "$loc/contents/lockscreen/$f"; cp "$src/$f" "$loc/contents/lockscreen/$f"; done
# KPackage no lee archivos enlazados fuera del paquete: la configuración va copiada
for f in config.xml config.qml; do rm -f "$loc/contents/lockscreen/$f"; cp "$sis/contents/lockscreen/$f" "$loc/contents/lockscreen/$f"; done
# fondo: el mismo que el del escritorio, como en macOS (fondos animados de waywallen incluidos)
img=$(grep -m1 "^Image=" ~/.config/plasma-org.kde.plasma.desktop-appletsrc 2>/dev/null | cut -d= -f2-)
[ -n "$img" ] && kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "$img"
if grep -q "^wallpaperplugin=org.waywallen.kde$" ~/.config/plasma-org.kde.plasma.desktop-appletsrc 2>/dev/null; then
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.waywallen.kde
elif [ -n "$img" ]; then
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
fi
echo "pantalla de bloqueo de Vitrum instalada en $loc"
