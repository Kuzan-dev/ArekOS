#!/bin/bash
# ==============================================================================
# ArekOS (Vitrum KDE) — Instalador de 1 línea para cualquier usuario en KDE Plasma 6
#
# Uso directo:
#   bash ~/Documentos/ArekOS/install.sh            # Instala para tu usuario actual
#   bash ~/Documentos/ArekOS/install.sh --compilar # Recompila desde código fuente (en Podman o nativo) e instala
#
# Qué instala (100 % en $HOME, sin tocar archivos del sistema ni requerir root):
#   - Barra de menús estilo macOS Sequoia (menú del logo, nombre de app activa, menú global,
#     bandeja mínima, Spotlight, Centro de Control y fecha/reloj con tipografía Inter)
#   - Dock propio con esquina continua de macOS (squircle), ampliación suave, vista previa
#     de ventanas en vivo (PipeWire), ocultación al maximizar, Launchpad y Spotlight (Milou)
#   - Ajuste de material translúcido 1:1 con macOS Monterey/Sequoia + efecto KWin vitrumblur
#     (con guardián ante actualizaciones de KWin y servicio de recompilación automática)
#   - Decoración de ventanas propia con semáforos medidos en macOS (12 px, paso 20 px, barra 28 px)
#   - Estilo de aplicaciones Darkly parcheado (barra lateral translúcida en Dolphin, menús
#     translúcidos con texto desactivado al 30 % de alfa como en macOS)
#   - Esquemas de color Vitrum Claro / Oscuro, iconos y cursores WhiteSur, fuentes Inter y
#     JetBrains Mono, y app propia de "Ajustes del Sistema" + Vista rápida (Super+Y)
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILAR=false
APLICAR_EN_VIVO=true

for arg in "$@"; do
    case "$arg" in
        --compilar) COMPILAR=true ;;
        --sin-reiniciar-plasma) APLICAR_EN_VIVO=false ;;
    esac
done

echo "==> [1/7] Preparando directorios en $HOME..."
mkdir -p \
    "$HOME/.local/bin" \
    "$HOME/.local/lib64/qt6/plugins/styles" \
    "$HOME/.local/lib64/qt6/plugins/kstyle_config" \
    "$HOME/.local/lib64/qt6/plugins/org.kde.kdecoration3" \
    "$HOME/.local/lib64/qt6/plugins/kwin/effects/plugins" \
    "$HOME/.local/share/vitrum-ajustes" \
    "$HOME/.local/share/vitrum" \
    "$HOME/.local/share/plasma/plasmoids" \
    "$HOME/.local/share/icons/hicolor/scalable/apps" \
    "$HOME/.local/share/kio/servicemenus" \
    "$HOME/.local/share/applications" \
    "$HOME/.local/share/dbus-1/services" \
    "$HOME/.local/share/kglobalaccel" \
    "$HOME/.config/autostart" \
    "$HOME/.config/environment.d" \
    "$HOME/.config/plasma-workspace/env" \
    "$HOME/.config/systemd/user/plasma-workspace.target.wants" \
    "$HOME/.config/systemd/user/timers.target.wants" \
    "$HOME/.cache/vitrum-src"

# Copiar código fuente a ~/.cache/vitrum-src para que el servicio de auto-recompilación
# de vitrumblur ante actualizaciones de KWin tenga siempre las herramientas a mano
cp -r "$REPO_DIR/ajustes" "$REPO_DIR/centro-control" "$REPO_DIR/decoracion" \
      "$REPO_DIR/iconos" "$REPO_DIR/integracion" "$REPO_DIR/kwin-desenfoque" \
      "$REPO_DIR/menu-apple" "$REPO_DIR/nombre-app" "$REPO_DIR/scripts" \
      "$REPO_DIR/spotlight" "$REPO_DIR/tema-plasma" "$REPO_DIR/temas" \
      "$REPO_DIR/darkly" "$HOME/.cache/vitrum-src/"

echo "==> [2/7] Descomprimiendo iconos WhiteSur, fuentes Inter/JetBrains Mono, esquemas y temas..."
zstd -dc "$REPO_DIR/paquetes/recursos.tar.zst" | tar -C "$HOME/.local/share" -xf -
fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true

# Regenerar esquemas y temas de Plasma para asegurar rutas exactas del usuario actual
python3 "$REPO_DIR/scripts/vitrum-esquemas" >/dev/null
python3 "$REPO_DIR/tema-plasma/generar.py" >/dev/null
python3 "$REPO_DIR/temas/generar.py" >/dev/null

echo "==> [3/7] Instalando binarios y plugins de Qt6 / KWin..."
KWIN_VER="$(rpm -q --qf '%{VERSION}-%{RELEASE}' kwin 2>/dev/null || echo unknown)"
BINS_DIR="$REPO_DIR/binarios"

if [ "$COMPILAR" = true ] || [ ! -f "$BINS_DIR/vitrum-ajustes" ]; then
    echo "    Compilando componentes desde código fuente con Podman..."
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    FEDORA_VER="$(rpm -E %fedora 2>/dev/null || echo 44)"
    W="$HOME/.cache/vitrum-src/build-all"
    rm -rf "$W" && mkdir -p "$W/out"
    zstd -dc "$REPO_DIR/darkly/darkly-src.tar.zst" | tar -C "$HOME/.cache/vitrum-src" -xf -
    python3 "$REPO_DIR/darkly/parchear-menus.py" "$HOME/.cache/vitrum-src/darkly/kstyle/darklystyle.cpp" >/dev/null

    podman run --rm \
        -v "$HOME/.cache/vitrum-src:/src:Z,ro" \
        -v "$W/out:/out:Z" \
        "registry.fedoraproject.org/fedora:$FEDORA_VER" bash -c "
        set -e
        dnf -y -q --disablerepo=updates install --setopt=install_weak_deps=False \
            cmake gcc-c++ extra-cmake-modules kwin-devel qt6-qtbase-devel qt6-qtbase-private-devel \
            qt6-qtdeclarative-devel kf6-kwindowsystem-devel kf6-kconfig-devel kf6-kconfigwidgets-devel \
            kf6-kservice-devel kf6-kcmutils-devel kf6-kcoreaddons-devel kf6-kcolorscheme-devel \
            kf6-kguiaddons-devel kf6-ki18n-devel kf6-kiconthemes-devel kf6-frameworkintegration-devel \
            kf6-kirigami-devel kdecoration-devel libepoxy-devel wayland-devel libxcb-devel \
            libdrm-devel mesa-libgbm-devel libxkbcommon-devel pipewire-devel lcms2-devel \
            libdisplay-info-devel gettext >/dev/null
        # 1) vitrum-ajustes
        cmake -S /src/ajustes -B /tmp/b-aj -DCMAKE_BUILD_TYPE=Release >/dev/null
        cmake --build /tmp/b-aj -j\$(nproc) >/dev/null
        cp /tmp/b-aj/vitrum-ajustes /out/
        # 2) org.vitrum.decoracion.so
        cmake -S /src/decoracion -B /tmp/b-dec -DCMAKE_BUILD_TYPE=Release >/dev/null
        cmake --build /tmp/b-dec -j\$(nproc) >/dev/null
        find /tmp/b-dec -name 'org.vitrum.decoracion.so' -exec cp {} /out/ \;
        # 3) darkly6.so
        cmake -S /src/darkly -B /tmp/b-dk -DCMAKE_BUILD_TYPE=Release -DBUILD_QT5=OFF -DBUILD_QT6=ON -DWITH_DECORATIONS=OFF -DBUILD_TESTING=OFF >/dev/null
        cmake --build /tmp/b-dk -j\$(nproc) >/dev/null
        find /tmp/b-dk -name 'darkly6.so' -exec cp {} /out/ \;
        find /tmp/b-dk -name 'darklystyleconfig.so' -exec cp {} /out/ \;
        # 4) vitrumblur.so
        cmake -S /src/kwin-desenfoque -B /tmp/b-kd -DCMAKE_BUILD_TYPE=Release >/dev/null
        cmake --build /tmp/b-kd -j\$(nproc) >/dev/null
        find /tmp/b-kd -name 'vitrumblur.so' -exec cp {} /out/ \;
        rpm -q --qf '%{VERSION}-%{RELEASE}' kwin-devel > /out/kwin-version
    " 2>&1 | grep -v level=warn || true
    BINS_DIR="$W/out"
fi

# Instalación atómica de binarios y bibliotecas (.so) para no tumbar procesos en ejecución
instalar_bin() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 0
    cmp -s "$src" "$dst" 2>/dev/null && return 0
    cp "$src" "$dst.nuevo" && chmod +x "$dst.nuevo" && mv -f "$dst.nuevo" "$dst"
}

instalar_bin "$BINS_DIR/vitrum-ajustes" "$HOME/.local/bin/vitrum-ajustes"
instalar_bin "$BINS_DIR/darkly6.so" "$HOME/.local/lib64/qt6/plugins/styles/darkly6.so"
instalar_bin "$BINS_DIR/darklystyleconfig.so" "$HOME/.local/lib64/qt6/plugins/kstyle_config/darklystyleconfig.so"
instalar_bin "$BINS_DIR/org.vitrum.decoracion.so" "$HOME/.local/lib64/qt6/plugins/org.kde.kdecoration3/org.vitrum.decoracion.so"
instalar_bin "$BINS_DIR/vitrumblur.so" "$HOME/.local/lib64/qt6/plugins/kwin/effects/plugins/vitrumblur.so"
[ -f "$BINS_DIR/kwin-version" ] && cp "$BINS_DIR/kwin-version" "$HOME/.local/share/vitrum/desenfoque-kwin"

# Si la versión de KWin del sistema es distinta a la del binario precompilado, recompilar vitrumblur
if [ -f "$HOME/.local/share/vitrum/desenfoque-kwin" ] && [ "$(cat "$HOME/.local/share/vitrum/desenfoque-kwin")" != "$KWIN_VER" ]; then
    echo "    KWin del sistema ($KWIN_VER) difiere del precompilado; adaptando vitrumblur..."
    "$REPO_DIR/scripts/vitrum-desenfoque-construir" --forzar || true
fi

echo "==> [4/7] Instalando QML, plasmoides, iconos y scripts..."
rm -rf "$HOME/.local/share/vitrum-ajustes/qml"
cp -r "$REPO_DIR/ajustes/qml" "$HOME/.local/share/vitrum-ajustes/"

for s in vitrum-modo vitrum-plasma-set vitrum-disposicion vitrum-esquemas vitrum-klassy \
         vitrum-bandeja vitrum-brillo vitrum-raton vitrum-pantalla-cambio \
         vitrum-cc-estado vitrum-cc-detalle vitrum-vista-rapida vitrum-desenfoque-construir; do
    cp "$REPO_DIR/scripts/$s" "$HOME/.local/bin/$s"
    chmod +x "$HOME/.local/bin/$s"
done

for p_src_dst in "centro-control:org.vitrum.centrocontrol" \
                 "menu-apple:org.vitrum.menuapple" \
                 "spotlight:org.vitrum.spotlight" \
                 "nombre-app:org.vitrum.nombreapp"; do
    src="${p_src_dst%%:*}"
    dst="${p_src_dst##*:}"
    rm -rf "$HOME/.local/share/plasma/plasmoids/$dst"
    cp -r "$REPO_DIR/$src" "$HOME/.local/share/plasma/plasmoids/$dst"
done

cp "$REPO_DIR/iconos/"*.svg "$HOME/.local/share/icons/hicolor/scalable/apps/"

echo "==> [5/7] Configurando servicios systemd, D-Bus, variables de entorno y accesos directos..."
cp "$REPO_DIR/integracion/vitrum-vista-rapida.desktop" \
   "$REPO_DIR/integracion/vitrum-escritorio.desktop" \
   "$HOME/.local/share/kio/servicemenus/"
chmod +x "$HOME/.local/share/kio/servicemenus/vitrum-"*.desktop

cp "$REPO_DIR/integracion/org.vitrum.vistarapida.desktop" \
   "$REPO_DIR/integracion/org.vitrum.spotlight-atajo.desktop" \
   "$REPO_DIR/integracion/org.vitrum.launchpad.desktop" \
   "$HOME/.local/share/applications/"

cat > "$HOME/.local/share/applications/org.vitrum.ajustes.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ajustes del Sistema
Comment=Configura el escritorio
Exec=$HOME/.local/bin/vitrum-ajustes %u
Icon=preferences-system
Categories=Settings;
StartupWMClass=org.vitrum.ajustes
X-KDE-Wayland-Interfaces=org_kde_plasma_window_management,org_kde_plasma_activation_feedback,zkde_screencast_unstable_v1
EOF

# Entorno para que Qt6 y KWin carguen Darkly, org.vitrum.decoracion y vitrumblur desde ~/.local
cat > "$HOME/.config/plasma-workspace/env/vitrum.sh" <<'EOF'
# Vitrum: plugins de estilo, decoración y efectos instalados en el usuario
export QT_PLUGIN_PATH=$HOME/.local/opt/kvantum/plugins:$HOME/.local/lib64/qt6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}
export LD_LIBRARY_PATH=$HOME/.local/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PATH=$HOME/.local/bin:$HOME/.local/opt/kvantum/bin:$PATH
EOF

cp "$REPO_DIR/integracion/vitrum-desenfoque-guardian.sh" "$HOME/.config/plasma-workspace/env/"

cat > "$HOME/.config/environment.d/60-vitrum-plugins.conf" <<EOF
QT_PLUGIN_PATH=$HOME/.local/opt/kvantum/plugins:$HOME/.local/lib64/qt6/plugins
LD_LIBRARY_PATH=$HOME/.local/lib64
EOF

cat > "$HOME/.config/environment.d/90-kwin-color-pipeline.conf" <<'EOF'
# Evita el crash de KWin 6.6.4 en DrmAbstractColorOp::matchPipeline (NVIDIA)
KWIN_DRM_USE_COLOR_PIPELINE=0
EOF

# Servicios systemd de usuario (Dock/Shell, modo automático y auto-recompilación de vitrumblur)
rm -f "$HOME/.config/autostart/vitrum-shell.desktop"
cat > "$HOME/.config/systemd/user/vitrum-shell.service" <<'EOF'
[Unit]
Description=Vitrum: dock, Launchpad y Spotlight
PartOf=graphical-session.target
After=plasma-plasmashell.service
[Service]
ExecStart=%h/.local/bin/vitrum-ajustes --shell
Restart=on-failure
RestartSec=2
Slice=session.slice
[Install]
WantedBy=plasma-workspace.target
EOF
ln -sf ../vitrum-shell.service "$HOME/.config/systemd/user/plasma-workspace.target.wants/vitrum-shell.service"

cat > "$HOME/.config/systemd/user/vitrum-modo.service" <<'EOF'
[Unit]
Description=Vitrum: cambia entre claro y oscuro en modo automático
[Service]
Type=oneshot
ExecStart=%h/.local/bin/vitrum-modo --temporizador
EOF

cat > "$HOME/.config/systemd/user/vitrum-modo.timer" <<'EOF'
[Unit]
Description=Vitrum: comprueba el modo automático cada 10 minutos
[Timer]
OnStartupSec=20s
OnUnitActiveSec=10min
[Install]
WantedBy=timers.target
EOF
ln -sf ../vitrum-modo.timer "$HOME/.config/systemd/user/timers.target.wants/vitrum-modo.timer"

cat > "$HOME/.config/systemd/user/vitrum-desenfoque.service" <<'EOF'
[Unit]
Description=Vitrum: recompila el desenfoque propio si KWin se ha actualizado
After=plasma-workspace.target
[Service]
Type=oneshot
Nice=15
ExecStart=%h/.local/bin/vitrum-desenfoque-construir
[Install]
WantedBy=plasma-workspace.target
EOF
ln -sf ../vitrum-desenfoque.service "$HOME/.config/systemd/user/plasma-workspace.target.wants/vitrum-desenfoque.service"

cat > "$HOME/.local/share/dbus-1/services/org.vitrum.Shell.service" <<EOF
[D-BUS Service]
Name=org.vitrum.Shell
Exec=$HOME/.local/bin/vitrum-ajustes --shell
SystemdService=vitrum-shell.service
EOF

# Desactivar KRunner y el icono de XWayland Video Bridge
printf "[D-BUS Service]\nName=org.kde.krunner\nExec=/bin/false\n" > "$HOME/.local/share/dbus-1/services/org.kde.krunner.service"
ln -sfn /dev/null "$HOME/.config/systemd/user/plasma-krunner.service"
printf "[Desktop Entry]\nHidden=true\n" > "$HOME/.config/autostart/org.kde.xwaylandvideobridge.desktop"
if [ -f /usr/share/kglobalaccel/org.kde.krunner.desktop ]; then
    sed "s/^X-KDE-Shortcuts=Alt+Space,Alt+F2,Search$/X-KDE-Shortcuts=Alt+F2,Search/" \
        /usr/share/kglobalaccel/org.kde.krunner.desktop > "$HOME/.local/share/kglobalaccel/org.kde.krunner.desktop"
fi

echo "==> [6/7] Aplicando tipografía Inter, cursores WhiteSur, estilo Darkly, decoración y efectos KWin..."
for k_font in \
    "font:Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" \
    "menuFont:Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" \
    "toolBarFont:Inter,9,-1,5,400,0,0,0,0,0,0,0,0,0,1" \
    "smallestReadableFont:Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" \
    "fixed:JetBrains Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"; do
    kwriteconfig6 --file kdeglobals --group General --key "${k_font%%:*}" "${k_font#*:}"
done
kwriteconfig6 --file kdeglobals --group WM --key activeFont "Inter,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme WhiteSur-cursors

# Configuración de Dock por defecto si aún no existe vitrumrc
if [ ! -f "$HOME/.config/vitrumrc" ]; then
    kwriteconfig6 --file vitrumrc --group Apariencia --key Modo oscuro
    kwriteconfig6 --file vitrumrc --group Dock --key Autohide false
    kwriteconfig6 --file vitrumrc --group Dock --key Magnification true
    kwriteconfig6 --file vitrumrc --group Dock --key MagnificationSize 77
    kwriteconfig6 --file vitrumrc --group Dock --key Position bottom
    kwriteconfig6 --file vitrumrc --group Dock --key TileSize 64
fi

# Ejecutar el guardián de desenfoque y la configuración de estilo/decoración
. "$HOME/.config/plasma-workspace/env/vitrum-desenfoque-guardian.sh"
"$HOME/.local/bin/vitrum-klassy"

echo "==> [7/7] Aplicando disposición de barra de menús, Dock, atajos y tema..."
# Respaldo de seguridad de la disposición previa
[ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ] && \
   [ ! -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc.antes-arekos" ] && \
   cp -p "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc.antes-arekos"
[ -f "$HOME/.config/kglobalshortcutsrc" ] && \
   [ ! -f "$HOME/.config/kglobalshortcutsrc.antes-arekos" ] && \
   cp -p "$HOME/.config/kglobalshortcutsrc" "$HOME/.config/kglobalshortcutsrc.antes-arekos"

if [ "$APLICAR_EN_VIVO" = true ] && systemctl --user -q is-active plasma-plasmashell.service 2>/dev/null; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user stop plasma-plasmashell.service || true
    python3 "$HOME/.local/bin/vitrum-disposicion"
    systemctl --user start plasma-plasmashell.service || true
    "$HOME/.local/bin/vitrum-modo" "$(kreadconfig6 --file vitrumrc --group Apariencia --key Modo --default oscuro)" --aplicar || true
    # Aplicar fondo de pantalla Vitrum (con variantes clara y oscura) en todos los escritorios
    WALL_PATH="$HOME/.local/share/wallpapers/Vitrum"
    [ -d "$WALL_PATH" ] && plasma-apply-wallpaperimage "$WALL_PATH" >/dev/null 2>&1 || true
    systemctl --user enable --now vitrum-shell.service vitrum-modo.timer >/dev/null 2>&1 || true
    systemctl --user restart vitrum-shell.service >/dev/null 2>&1 || true
else
    python3 "$HOME/.local/bin/vitrum-disposicion"
    QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$HOME/.local/bin/vitrum-modo" oscuro --aplicar >/dev/null 2>&1 || true
fi

kbuildsycoca6 >/dev/null 2>&1 || true

echo ""
echo "=============================================================================="
echo " ArekOS (Vitrum KDE) instalado correctamente en el usuario: $(whoami)"
echo " - Si acabas de instalarlo por primera vez, cierra sesión y vuelve a entrar"
echo "   para que KWin cargue QT_PLUGIN_PATH (decoración de semáforos y vitrumblur)."
echo "=============================================================================="
