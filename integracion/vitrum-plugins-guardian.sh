# Vitrum: guardián de la decoración propia y del estilo Darkly (se ejecuta al iniciar sesión, antes que KWin).
# Ambos están compilados para una versión concreta de kdecoration y Qt: si Fedora los actualiza a otra versión
# (6.7 → 6.8), cargarlos puede tumbar KWin o las apps. En ese caso se usan Breeze (decoración y estilo) hasta que
# se recompilen («install.sh --compilar»), y al volver a coincidir se restauran los de Vitrum.
# Mientras no coinciden existe ~/.local/share/vitrum/plugins-incompatibles (vitrum-klassy lo respeta).
_vitrum_compilado=$(cat "$HOME/.local/share/vitrum/plugins-compilados" 2>/dev/null)
_vitrum_actual="kdecoration $(rpm -q --qf '%{VERSION}' kdecoration 2>/dev/null | cut -d. -f1,2) qt $(rpm -q --qf '%{VERSION}' qt6-qtbase 2>/dev/null | cut -d. -f1,2)"
_vitrum_marca="$HOME/.local/share/vitrum/plugins-incompatibles"
if [ -z "$_vitrum_compilado" ] || [ "$_vitrum_compilado" = "$_vitrum_actual" ]; then
    if [ -f "$_vitrum_marca" ]; then
        [ "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)" = org.kde.breeze ] && \
            kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.vitrum.decoracion
        [ "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" = Breeze ] && \
            kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly
        rm -f "$_vitrum_marca"
    fi
else
    [ -f "$_vitrum_marca" ] || logger -t vitrum "plugins compilados para «$_vitrum_compilado» y el sistema tiene «$_vitrum_actual»: se usa Breeze hasta ejecutar install.sh --compilar"
    echo "$_vitrum_actual" > "$_vitrum_marca"
    [ "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)" = org.vitrum.decoracion ] && \
        kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
    [ "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" = Darkly ] && \
        kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze
fi
unset _vitrum_compilado _vitrum_actual _vitrum_marca
