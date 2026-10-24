#!/bin/bash
# Compila vitrum-login-greeter (cuenta vitrum, contenedor fedora con las versiones del sistema: --disablerepo=updates;
# con «updates» enlazaría contra un Qt más nuevo que el instalado y no arrancaría).
# Uso: construir.sh <código de plasma-login-manager de la versión instalada>   → deja el binario en login-build/out
set -euo pipefail
src=$1
tmp=$(mktemp -d); cp -r "$src" "$tmp/plm"; rm -rf "$tmp/plm/.git"
python3 "$(dirname "$0")/parchear.py" "$tmp/plm"
sudo -u vitrum rm -rf /home/vitrum/.cache/vitrum-src/login-build/plm
sudo -u vitrum mkdir -p /home/vitrum/.cache/vitrum-src/login-build
tar -C "$tmp" -cf - plm | sudo -n -u vitrum tar -C /home/vitrum/.cache/vitrum-src/login-build -xf -
rm -rf "$tmp"
sudo -n -u vitrum -H bash -c '
cd ~; unset SUDO_UID SUDO_GID SUDO_USER SUDO_COMMAND; export XDG_RUNTIME_DIR=/tmp/vitrum-podman; mkdir -p -m 700 $XDG_RUNTIME_DIR
cd ~/.cache/vitrum-src/login-build; rm -rf out; mkdir out
podman run --rm -v $PWD/plm:/src:Z,ro -v $PWD/out:/out:Z registry.fedoraproject.org/fedora:44 bash -c "
dnf -y -q --disablerepo=updates install dnf-plugins-core >/dev/null 2>&1
dnf -y -q --disablerepo=updates --enablerepo=fedora-source builddep plasma-login-manager >/tmp/bd.log 2>&1 || { tail -5 /tmp/bd.log; exit 1; }
cmake -S /src -B /tmp/b -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF >/tmp/c.log 2>&1 || { tail -20 /tmp/c.log; exit 1; }
cmake --build /tmp/b -j16 --target plasma-login-greeter >/tmp/m.log 2>&1 || { grep -B2 -A6 error /tmp/m.log | head -40; exit 1; }
find /tmp/b -name plasma-login-greeter -type f -exec cp {} /out/vitrum-login-greeter \; ; echo COMPILADO" 2>&1 | grep -v level=warn'
