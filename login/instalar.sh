#!/bin/bash
# Instala (como root) la pantalla de inicio de sesión de Vitrum sobre Plasma Login, sin tocar ningún archivo de
# Fedora: todo va en /usr/local y /etc, y se deshace con «vitrum-login-restaurar».
#   instalar.sh <vitrum-login-greeter compilado> <imagen de fondo> [usuario cuyas pantallas (HDR) copiar]
#   instalar.sh --quitar
# Red de seguridad: el servicio del greeter arranca vitrum-login-lanzador, que usa la pantalla original de Fedora
# si existe /etc/vitrum/login-desactivado, si Plasma Login se ha actualizado (versión distinta de la compilada) o
# si la de Vitrum falla al arrancar.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "ejecútalo con sudo"; exit 1; }

drop=/etc/systemd/user/plasma-login.service.d/vitrum.conf
if [ "${1:-}" = --quitar ]; then
    exec /usr/local/sbin/vitrum-login-restaurar
fi

bin=$1; fondo=$2; usuario=${3:-${SUDO_USER:-}}
install -d /usr/local/libexec /usr/local/sbin /usr/local/share/vitrum /etc/vitrum "$(dirname "$drop")"
install -m 755 "$bin" /usr/local/libexec/vitrum-login-greeter
# huella del greeter de Fedora con el que se compiló: si cambia (actualización), se usa el de Fedora
stat -c '%s %Y' /usr/libexec/plasma-login-greeter > /usr/local/share/vitrum/login-version
install -m 644 "$fondo" /usr/local/share/vitrum/login-fondo.jpg

cat > /usr/local/libexec/vitrum-login-lanzador <<'EOF'
#!/bin/bash
# Vitrum: arranca la pantalla de inicio de sesión de Vitrum y, ante cualquier problema, la original de Fedora.
orig=/usr/libexec/plasma-login-greeter
mio=/usr/local/libexec/vitrum-login-greeter
args=("$@")
fedora() { logger -t vitrum-login "$1: uso la pantalla original de Fedora"; exec "$orig" "${args[@]}"; }
[ -e /etc/vitrum/login-desactivado ] && fedora "desactivada a mano (/etc/vitrum/login-desactivado)"
[ -x "$mio" ] || fedora "no está instalada"
[ "$(stat -c '%s %Y' "$orig")" = "$(cat /usr/local/share/vitrum/login-version 2>/dev/null)" ] \
    || fedora "Plasma Login se ha actualizado (hay que recompilar la de Vitrum)"
"$mio" "$@"
rc=$?
# 0: terminó bien; 129/130/137/143: el sistema la cerró (inicio de sesión hecho, apagado…)
case $rc in 0|129|130|137|143) exit $rc ;; esac
fedora "la de Vitrum falló (código $rc)"
EOF
chmod 755 /usr/local/libexec/vitrum-login-lanzador

cat > /usr/local/libexec/vitrum-login-fondo <<'EOF'
#!/bin/bash
# Vitrum: cambia el fondo de la pantalla de inicio de sesión (Ajustes → Pantalla de bloqueo). Se ejecuta con
# pkexec (pide la contraseña de administrador): la pantalla de inicio es común a todos los usuarios.
# Uso: vitrum-login-fondo <imagen jpg/png/webp>
src=$1
[ -f "$src" ] || { echo "no existe: $src"; exit 1; }
ext=$(printf '%s' "${src##*.}" | tr 'A-Z' 'a-z')
case "$ext" in jpg|jpeg|png|webp) ;; *) echo "formato no admitido"; exit 2 ;; esac
d=/usr/local/share/vitrum
install -d "$d"
install -m 644 "$src" "$d/login-fondo.nuevo.$ext"
rm -f "$d"/login-fondo.jpg "$d"/login-fondo.jpeg "$d"/login-fondo.png "$d"/login-fondo.webp
mv -f "$d/login-fondo.nuevo.$ext" "$d/login-fondo.$ext"
restorecon "$d/login-fondo.$ext" 2>/dev/null || true
kwriteconfig6 --file /etc/plasmalogin.conf --group Greeter --key WallpaperPluginId org.kde.image
kwriteconfig6 --file /etc/plasmalogin.conf --group Greeter --group Wallpaper --group org.kde.image --group General \
    --key Image "file://$d/login-fondo.$ext"
EOF
chmod 755 /usr/local/libexec/vitrum-login-fondo

cat > /usr/local/sbin/vitrum-login-restaurar <<'EOF'
#!/bin/bash
# Vitrum: deja la pantalla de inicio de sesión exactamente como la instala Fedora.
# Uso (desde una consola de texto Ctrl+Alt+F3, o arrancando con systemd.unit=multi-user.target):
#   sudo vitrum-login-restaurar
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
rm -f /etc/systemd/user/plasma-login.service.d/vitrum.conf
rmdir /etc/systemd/user/plasma-login.service.d 2>/dev/null
systemctl disable --now vitrum-login-pantallas.path 2>/dev/null
c=/var/lib/plasmalogin/.config/kwinoutputconfig.json
[ -f $c.original-fedora ] && cp -f $c.original-fedora $c && chown plasmalogin:plasmalogin $c
[ -f /etc/plasmalogin.conf.antes-vitrum ] && cp -f /etc/plasmalogin.conf.antes-vitrum /etc/plasmalogin.conf
systemctl daemon-reload
echo "Pantalla de inicio de sesión de Fedora restaurada."
if [ "$(systemctl get-default)" = graphical.target ] && ! systemctl is-active -q graphical.target; then
    echo "Arrancado en modo texto: ejecuta «sudo systemctl isolate graphical.target» o reinicia."
else
    echo "Se verá la próxima vez que aparezca (o ahora con «sudo systemctl restart plasmalogin», que cierra las sesiones)."
fi
EOF
chmod 755 /usr/local/sbin/vitrum-login-restaurar

# fondo (el usuario plasmalogin no puede leer los archivos de /home)
[ -f /etc/plasmalogin.conf.antes-vitrum ] || cp /etc/plasmalogin.conf /etc/plasmalogin.conf.antes-vitrum
kwriteconfig6 --file /etc/plasmalogin.conf --group Greeter --key WallpaperPluginId org.kde.image
kwriteconfig6 --file /etc/plasmalogin.conf --group Greeter --group Wallpaper --group org.kde.image --group General \
    --key Image file:///usr/local/share/vitrum/login-fondo.jpg

# misma configuración de pantallas (HDR, brillo SDR, disposición) que el usuario, copiada cada vez que la cambie
if [ -n "$usuario" ] && home=$(getent passwd "$usuario" | cut -d: -f6) && [ -d "$home" ]; then
    cat > /usr/local/libexec/vitrum-login-pantallas <<FIN
#!/bin/bash
# Vitrum: la pantalla de inicio de sesión (usuario plasmalogin) usa la configuración de pantallas de $usuario.
src=$home/.config/kwinoutputconfig.json
dst=/var/lib/plasmalogin/.config/kwinoutputconfig.json
[ -s "\$src" ] || exit 0
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "\$src" || exit 0   # solo JSON válido
install -o plasmalogin -g plasmalogin -m 644 "\$src" "\$dst.nuevo" && mv -f "\$dst.nuevo" "\$dst"
FIN
    chmod 755 /usr/local/libexec/vitrum-login-pantallas
    c=/var/lib/plasmalogin/.config/kwinoutputconfig.json
    [ -f $c ] && [ ! -f $c.original-fedora ] && cp $c $c.original-fedora
    cat > /etc/systemd/system/vitrum-login-pantallas.service <<FIN
[Unit]
Description=Vitrum: copia la configuración de pantallas (HDR) de $usuario a la pantalla de inicio de sesión
[Service]
Type=oneshot
ExecStart=/usr/local/libexec/vitrum-login-pantallas
FIN
    cat > /etc/systemd/system/vitrum-login-pantallas.path <<FIN
[Unit]
Description=Vitrum: vigila la configuración de pantallas de $usuario
[Path]
PathChanged=$home/.config/kwinoutputconfig.json
Unit=vitrum-login-pantallas.service
[Install]
WantedBy=multi-user.target
FIN
    semanage fcontext -a -t bin_t '/usr/local/libexec/vitrum-login-pantallas' 2>/dev/null || true
    restorecon /usr/local/libexec/vitrum-login-pantallas 2>/dev/null || true
    systemctl daemon-reload
    systemctl enable --now vitrum-login-pantallas.path >/dev/null 2>&1 || true
    systemctl start vitrum-login-pantallas.service || true
fi

cat > "$drop" <<'EOF'
# Vitrum: pantalla de inicio de sesión estilo macOS, con vuelta automática a la de Fedora si falla.
# Se quita con: sudo vitrum-login-restaurar
[Service]
ExecStart=
ExecStart=/usr/local/libexec/vitrum-login-lanzador
EOF
# misma etiqueta SELinux que el greeter de Fedora (xdm_exec_t), para que se ejecuten igual que él
semanage fcontext -a -t xdm_exec_t '/usr/local/libexec/vitrum-login-(greeter|lanzador)' 2>/dev/null \
    || semanage fcontext -m -t xdm_exec_t '/usr/local/libexec/vitrum-login-(greeter|lanzador)' 2>/dev/null || true
restorecon -R /usr/local/libexec /usr/local/sbin /usr/local/share/vitrum /etc/systemd/user 2>/dev/null || true
systemctl daemon-reload
echo "instalada (se verá la próxima vez que aparezca la pantalla de inicio de sesión)"
