# ArekOS (Vitrum KDE)

Entorno completo estilo **macOS Sequoia / Monterey** para **KDE Plasma 6 (Wayland)**, diseñado para instalarse 100 % dentro del directorio del usuario (`$HOME/.local` y `$HOME/.config`) sin tocar paquetes del sistema ni requerir permisos de administrador (`root`).

## Instalación en 1 línea de comandos

Para aplicar todo en tu usuario actual (o tras formatear / cambiar de PC):

```bash
bash ~/Documentos/ArekOS/install.sh
```

Si lo subes a un repositorio Git (GitHub / GitLab), puedes instalarlo en cualquier PC con una sola línea:

```bash
git clone <URL_DE_TU_REPO> ~/Documentos/ArekOS && bash ~/Documentos/ArekOS/install.sh
```

### Opciones del instalador

- **`bash ~/Documentos/ArekOS/install.sh`**: Instalación rápida usando los binarios incluidos (Fedora 44 / KDE Plasma 6.6) y aplicando toda la configuración en vivo. Si detecta una versión distinta de KWin, recompila automáticamente el efecto `vitrumblur`.
- **`bash ~/Documentos/ArekOS/install.sh --login`**: Además instala (con `sudo`) la pantalla de inicio de sesión estilo Sequoia sobre Plasma Login, en `/usr/local` y `/etc`, sin tocar archivos de Fedora. Si falla, si Plasma Login se actualiza o si existe `/etc/vitrum/login-desactivado`, arranca la de Fedora. Para quitarla: `sudo vitrum-login-restaurar` (también desde Ctrl+Alt+F3 o arrancando con `systemd.unit=multi-user.target` en GRUB).
- **`bash ~/Documentos/ArekOS/install.sh --waywallen`**: Además pone en el escritorio los fondos animados de Wallpaper Engine con [waywallen](https://github.com/waywallen/waywallen). Sin la opción, waywallen se instala igual (Flatpak, integración con Plasma, complemento de Wallpaper Engine, arranque automático, nombre real de cada monitor y ajuste para NVIDIA) pero el fondo no cambia. Los fondos se leen de la biblioteca de Steam (Wallpaper Engine instalado desde Steam); en la app se eligen y se aplican a cada monitor.
- **`bash ~/Documentos/ArekOS/install.sh --compilar`**: Recompila desde cero todos los componentes C++/Qt6/KWin (`vitrum-ajustes`, `org.vitrum.decoracion.so`, `darkly6.so` y `vitrumblur.so`) dentro de un contenedor Podman aislado con las versiones exactas del sistema y luego los instala.

> **Nota tras la primera instalación:** Una vez termine `install.sh`, **cierra sesión y vuelve a iniciar sesión** para que `kwin_wayland` tome las variables de entorno (`QT_PLUGIN_PATH` y `LD_LIBRARY_PATH`) y cargue la decoración de semáforos y el desenfoque de esquinas continuas (`vitrumblur`).

---

## Qué incluye el repositorio

| Carpeta / Archivo | Descripción |
|---|---|
| `install.sh` | Instalador automático de 1 línea (descomprime recursos, instala binarios/plasmoides, configura atajos y aplica el tema). |
| `ajustes/` | Código fuente C++/QML de `vitrum-ajustes`: **Ajustes del Sistema** (diseño macOS), **Shell** (`--shell`: Dock con esquina continua *squircle*, ampliación cosenoidal, vista previa PipeWire, Launchpad, Spotlight con Milou y Centro de Control) y **Vista rápida** (`--vista-rapida`). |
| `kwin-desenfoque/` | Efecto `vitrumblur` para KWin 6.6 con recorte SDF de esquina continua (*superelipse* $p=2.8$) + generador automático (`herramientas/parchear.py`) y guardián de actualizaciones de KWin. |
| `decoracion/` | Decoración de ventanas KDecoration3 (`org.vitrum.decoracion`) con las medidas exactas de los semáforos de macOS (12 px de diámetro, 20 px entre centros, barra de 28 px). |
| `darkly/` | Código fuente empaquetado de Darkly (`darkly-src.tar.zst`) y parche `parchear-menus.py` (barra lateral de Dolphin translúcida, sin flecha de menú retardado y texto deshabilitado de menús al 30 % de alfa como en macOS). |
| `bloqueo/` | Pantalla de bloqueo estilo Sequoia (hora con material vibrante, foto y campo en píldora); se instala como capa local sobre la de KDE. |
| `login/` | Pantalla de inicio de sesión estilo Sequoia para Plasma Login (`Main.qml`, `parchear.py`, `construir.sh`, `instalar.sh` con lanzador de seguridad y `vitrum-login-restaurar`). |
| `centro-control/`, `menu-apple/`, `nombre-app/`, `spotlight/` | Plasmoides de la barra de menús superior. |
| `tema-plasma/`, `temas/` | Generadores del tema de Plasma (`Vitrum` / `Vitrum-Oscuro`), temas globales (`org.vitrum.claro` / `org.vitrum.oscuro`), pantalla de cierre de sesión y fondo dinámico. |
| `scripts/` | Scripts de gestión (`vitrum-modo`, `vitrum-disposicion`, `vitrum-esquemas`, `vitrum-klassy`, `vitrum-bandeja`, `vitrum-brillo`, `vitrum-raton`, `vitrum-pantalla-cambio`, `vitrum-vista-rapida`, `vitrum-desenfoque-construir`). |
| `paquetes/recursos.tar.zst` | Paquete comprimido con los iconos y cursores `WhiteSur`, fuentes `Inter` y `JetBrains Mono`, esquemas de color y fondos de pantalla. |
| `binarios/` | Binarios precompilados listos para instalar sin esperar compilación. |

---

## Atajos de teclado (mantiene atajos clásicos de Linux/Windows)

Se conservan intactos `Ctrl+C`, `Ctrl+V`, `Ctrl+Z`, `Alt+Tab`, etc., y las funciones propias de macOS se asignan a la tecla `Super` (`Meta`):

- **`Super` (sola):** Launchpad
- **`Super + Espacio` / `Alt + Espacio` / `Super + S`:** Spotlight
- **`Super + Tab` / `Super + W`:** Mission Control (Vista general de KWin)
- **`Super + A`:** Centro de Control
- **`Super + N`:** Centro de Notificaciones
- **`Super + Y`:** Vista rápida del archivo seleccionado en Dolphin

---

## 🐧 Adaptación para CachyOS / Arch Linux (Guía de portabilidad)

ArekOS fue desarrollado y probado inicialmente sobre **Fedora 44 con KDE Plasma 6 (Wayland)**. La gran mayoría de los componentes (plasmoides QML, temas de Plasma, iconos WhiteSur, atajos y scripts KConfig) son 100 % compatibles con cualquier distribución que use Plasma 6.

Si deseas utilizar o adaptar este entorno en **CachyOS** o cualquier derivada de **Arch Linux**, ten en cuenta los siguientes puntos técnicos:

### 1. Compilación nativa en lugar de binarios precompilados
* Los binarios incluidos en `binarios/` y el contenedor Podman en `install.sh` están construidos con la cadena de bibliotecas de Fedora (glibc, Qt 6.x y KWin específicos).
* En CachyOS (rolling release), los plugins C++ (`vitrumblur.so`, `org.vitrum.decoracion.so`, `darkly6.so` y `vitrum-ajustes`) deben **compilarse nativamente** para enlazar con las versiones exactas del sistema host:
  ```bash
  # Paquetes requeridos en Arch / CachyOS:
  sudo pacman -S --needed cmake extra-cmake-modules gcc git base-devel \
      qt6-base qt6-declarative kwin kdecoration kf6-kservice kf6-kcmutils \
      kf6-kcoreaddons kf6-kcolorscheme kf6-kguiaddons kf6-ki18n kf6-kiconthemes \
      kf6-frameworkintegration kirigami libepoxy wayland libxcb libdrm \
      mesa libxkbcommon pipewire lcms2 libdisplay-info zstd
  ```

### 2. Detección de versiones del sistema
* En `install.sh`, la verificación de la versión de KWin utiliza `rpm -q kwin`.
* En CachyOS / Arch se debe consultar mediante pacman:
  ```bash
  KWIN_VER="$(pacman -Q kwin 2>/dev/null | awk '{print $2}' || echo unknown)"
  ```

### 3. Rutas de bibliotecas Qt6 (`lib` vs `lib64`)
* Arch y CachyOS instalan bibliotecas en `/usr/lib/` y esperan plugins de usuario en `$HOME/.local/lib/qt6/plugins/` (en lugar de `lib64`).
* Para asegurar compatibilidad total, añade ambas rutas a la variable de entorno:
  ```bash
  QT_PLUGIN_PATH="$HOME/.local/lib/qt6/plugins:$HOME/.local/lib64/qt6/plugins:${QT_PLUGIN_PATH:-}"
  ```

### 4. Pantalla de inicio de sesión (`--login`)
* La opción `--login` de `install.sh` está diseñada específicamente para `plasma-login-manager` (el greeter de Fedora sobre systemd-homed).
* CachyOS utiliza **SDDM** como gestor de inicio de sesión. Por tanto:
  * **No ejecutes `install.sh --login` en CachyOS/Arch** (la pantalla de inicio de sesión original de SDDM no debe reemplazarse con este script).
  * La **pantalla de bloqueo** (`bloqueo/`), en cambio, sí es 100 % compatible ya que funciona sobre `kscreenlocker` dentro de la sesión de KWin.

---

## Desarrollo y despliegue rápido (`desplegar-ajustes`)

Para realizar pruebas o desarrollar componentes sin reinstalar todo el entorno:

```bash
# Desplegar cambios en tu sesión actual:
./scripts/desplegar-ajustes

# Desplegar y recompilar la app de Ajustes en tu sesión:
./scripts/desplegar-ajustes --compilar

# Desplegar en un usuario de pruebas aislado (ej: 'vitrum'):
./scripts/desplegar-ajustes --usuario vitrum
```

