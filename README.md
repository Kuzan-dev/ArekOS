# ArekOS (Vitrum KDE)

**English** | [Español](README.es.md)

High-performance desktop environment for **KDE Plasma 6 (Wayland)**, engineered with design principles and visual craft inspired by the modern macOS aesthetic. Designed to be installed 100% in user space (`$HOME/.local` and `$HOME/.config`), without modifying system packages or requiring administrator (`root`) privileges.

![ArekOS Desktop](capturas/Escritorio.png)

---

## 🌟 Implemented Features Overview

| Component | Description |
|---|---|
| **Vitrum Dock with Advanced Blur** | Floating dock featuring continuous curvature (*squircle*), smooth cosine zoom on hover, live window previews via PipeWire, multi-instance support, and intelligent auto-hide. |
| **KWin Blur Effect (`vitrumblur`)** | Custom blur engine with signed distance field (SDF) continuous corner mask (*superellipse* $p=2.8$), color space correction (`vitrumcolor.glsl`) tailored for sRGB and linear-light/PQ HDR displays, and an automated watchdog service for KWin updates. |
| **Integrated Spotlight** | Centered floating global search powered by integrated Milou/KRunner within the same process and quick shortcuts (`Super + Space` / `Alt + Space`). |
| **Application Launchpad** | Fullscreen application grid with multi-page navigation, instant filtering, and fast launching. |
| **Top Bar & Control Center** | Global menu with system logo, application menus, Inter typography clock/date, minimalist system tray, and a Control Center with sliders and quick connectivity toggles. |
| **System Settings & Hot Corners** | Native configuration app with unified aesthetics and a **Hot Corners** setup modal to trigger Mission Control, Desktop, or Screen Lock. |
| **Lock Screen & Login** | Native KWin lock screen featuring vibrant time display and pill-shaped password input, plus a custom Plasma Login screen with automatic fallback to system defaults on failure. |
| **Dynamic Wallpapers & Waywallen** | Native integration with Wallpaper Engine (via Flatpak waywallen) for per-monitor animated wallpapers synchronized with screen lock. |
| **App Integrations (Steam & Zen)** | Automatic adaptation with left-aligned macOS window controls, 10px rounded corners, and integrated shadows without redundant titlebars. |

---

## 🔬 Engineering Highlight: Dock Blur & Materials (`vitrumblur`)

Achieving vibrant, smooth macOS-like blur on Linux/KWin without stair-stepped pixelated corners or artifacts on modern displays presents several technical challenges:

1. **Analytical Clipping with Signed Distance Fields (SDF):**  
   By default, KWin clips blur regions using integer pixel rectangles. In `vitrumblur`, surfaces declare their corner radius in the window title (`#r19`), and the shader computes a **continuous superellipse ($p=2.8$)** with subpixel antialiasing, achieving the iconic continuous *squircle* curvature of macOS.
2. **Adaptive Color Space for HDR (`vitrumcolor.glsl`):**  
   On HDR displays, linear light compositing excessively brightens transparent regions (creating a washed-out or "milky" appearance). We engineered a shader that decodes luminance to a gamma 2.2 space relative to the reference white, applies the tint and contrast matrices, and re-encodes to the display's transfer function (sRGB, PQ, or BT.1886).
3. **Update Watchdog:**  
   When KWin updates, external C++ plugins often break due to ABI changes. A systemd service (`vitrum-desenfoque-guardian.sh`) detects version changes and automatically recompiles the blur effect in the background at session startup.

---

## 📸 Gallery

### Global Search (Spotlight)
![Spotlight Search](capturas/SearchBar.png)

### App Launcher (Launchpad)
![Launchpad Launcher](capturas/MenuApps.png)

### Top Bar & Integrated Menus
![Menu Bar](capturas/menubar.png)

### System Elements & Settings
![System Elements](capturas/Elementos.png)

---

## 🚀 One-Line Installation

To apply everything to your current user:

```bash
bash ~/Documentos/ArekOS/install.sh
```

If cloning the repository on a fresh machine:

```bash
git clone https://github.com/Kuzan-dev/ArekOS.git ~/Documentos/ArekOS && bash ~/Documentos/ArekOS/install.sh
```

### Installer Options

- **`bash install.sh`**: Quick installation using precompiled binaries (Fedora / KDE Plasma 6). Automatically recompiles the `vitrumblur` effect if a different KWin version is detected.
- **`bash install.sh --login`**: Additionally installs (requires `sudo`) the Plasma Login screen under `/usr/local` and `/etc`, with a built-in safety fallback to Fedora defaults if an error occurs. To uninstall: `sudo vitrum-login-restaurar`.
- **`bash install.sh --waywallen`**: Installs and enables animated Wallpaper Engine backgrounds via [waywallen](https://github.com/waywallen/waywallen).
- **`bash install.sh --compilar`**: Recompiles all C++/Qt6/KWin components (`vitrum-ajustes`, `org.vitrum.decoracion.so`, `darkly6.so`, and `vitrumblur.so`) from source inside an isolated Podman container.

> **Note after first installation:** Once `install.sh` finishes, **log out and log back in** so that the `kwin_wayland` compositor picks up the environment variables (`QT_PLUGIN_PATH` and `LD_LIBRARY_PATH`) to load the traffic-light window decorations and `vitrumblur` effect.

---

## ⌨️ Keyboard Shortcuts

Standard Linux and PC shortcuts (`Ctrl+C`, `Ctrl+V`, `Alt+Tab`, etc.) are left completely intact, mapping fast desktop actions to the `Super` (`Meta`) key:

- **`Super` (alone):** Launchpad (application grid)
- **`Super + Space` / `Alt + Space` / `Super + S`:** Spotlight (global search)
- **`Super + Tab` / `Super + W`:** Mission Control (KWin window overview)
- **`Super + A`:** Control Center
- **`Super + N`:** Notification Center
- **`Super + Y`:** Quick file preview of selected file in Dolphin

---

## 🛠️ Development & Quick Deployment (`desplegar-ajustes`)

To test or develop components without reinstalling the entire environment:

```bash
# Deploy changes to your current session:
./scripts/desplegar-ajustes

# Deploy and recompile the Settings app in your session:
./scripts/desplegar-ajustes --compilar

# Deploy to an isolated test user (e.g. 'vitrum'):
./scripts/desplegar-ajustes --usuario vitrum
```

---

## 🐧 CachyOS / Arch Linux Adaptation (Portability Guide)

ArekOS was initially developed and tested on **Fedora with KDE Plasma 6 (Wayland)**. Most components (QML plasmoids, Plasma themes, WhiteSur icons, shortcuts, and KConfig scripts) are 100% compatible with any distribution running Plasma 6.

If you want to use or adapt this environment on **CachyOS** or any **Arch Linux** derivative, keep the following in mind:

1. **Native compilation instead of precompiled binaries:**  
   On CachyOS (rolling release), C++ plugins must be built natively against system dependencies:
   ```bash
   sudo pacman -S --needed cmake extra-cmake-modules gcc git base-devel \
       qt6-base qt6-declarative kwin kdecoration kf6-kservice kf6-kcmutils \
       kf6-kcoreaddons kf6-kcolorscheme kf6-kguiaddons kf6-ki18n kf6-kiconthemes \
       kf6-frameworkintegration kirigami libepoxy wayland libxcb libdrm \
       mesa libxkbcommon pipewire lcms2 libdisplay-info zstd
   ```
2. **Version detection:** In `install.sh`, replace `rpm -q kwin` with `pacman -Q kwin`.
3. **Qt6 plugin path:** Add both `lib` and `lib64` to `QT_PLUGIN_PATH`:
   ```bash
   QT_PLUGIN_PATH="$HOME/.local/lib/qt6/plugins:$HOME/.local/lib64/qt6/plugins:${QT_PLUGIN_PATH:-}"
   ```
4. **Login screen:** CachyOS uses **SDDM** by default, so do not run `install.sh --login` (the lock screen `bloqueo/`, however, is 100% compatible).

---

## ⚖️ Disclaimer

This is an independent open-source project for the free software community and **KDE Plasma** users. It is not affiliated, sponsored, endorsed, or associated in any way with **Apple Inc.**

All trademarks, product names, and company logos (including *Apple*, *macOS*, *Sequoia*, and *Monterey*) are the exclusive property of their respective owners and are used solely for descriptive and illustrative purposes as an aesthetic reference.
