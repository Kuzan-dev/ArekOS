# Vitrum: guardián del desenfoque propio (se ejecuta al iniciar sesión, antes que KWin).
# El "Desenfoque de Vitrum" está compilado para una versión concreta de KWin: si Fedora actualiza KWin, se usa
# el desenfoque de KDE (nada se rompe) hasta que vitrum-desenfoque.service lo recompile para la versión nueva.
_vitrum_kv=$(rpm -q --qf '%{VERSION}-%{RELEASE}' kwin 2>/dev/null)
if [ -f "$HOME/.local/lib64/qt6/plugins/kwin/effects/plugins/vitrumblur.so" ] \
   && [ "$(cat "$HOME/.local/share/vitrum/desenfoque-kwin" 2>/dev/null)" = "$_vitrum_kv" ]; then
    kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
    kwriteconfig6 --file kwinrc --group Plugins --key vitrumblurEnabled true
else
    kwriteconfig6 --file kwinrc --group Plugins --key vitrumblurEnabled false
    kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
fi
unset _vitrum_kv
