import QtQuick
import QtQuick.Layouts

// Escritorio y Dock: mismas opciones y orden que en macOS 15 Sequoia, más las de KWin que no tienen equivalente.
Page {
    id: p
    title: "Escritorio y Dock"
    function kwin(group, key, value) { Sys.writeConf("kwinrc", [group], key, value); p.kwinReconfigure() }
    function kwinConf(group, key, def) { return Sys.readConf("kwinrc", [group], key, def) }
    function dockConf(key, def) { return Sys.readConf("vitrumrc", ["Dock"], key, def) }
    function setDock(key, value) { Sys.writeConf("vitrumrc", ["Dock"], key, value) }

    // El dock lo dibuja vitrum-shell y relee esta configuración en vivo
    SectionHeader { text: "Dock" }
    Card {
        RowItem {
            title: "Tamaño"
            Txt { text: "Pequeño"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider {
                width: 170; from: 40; to: 96; stepSize: 2
                value: Number(p.dockConf("TileSize", "64"))
                onReleased: (v) => p.setDock("TileSize", String(Math.round(v)))
            }
            Txt { text: "Grande"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
        RowItem {
            title: "Ampliación"
            Txt { text: "Desactivada"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider {
                width: 170; from: 0; to: 100; stepSize: 1
                // 0 = sin ampliación; si no, tamaño ampliado entre el del Dock y 128 px
                value: p.dockConf("Magnification", "false") === "true"
                       ? Math.round((Number(p.dockConf("MagnificationSize", "96")) - 64) / 64 * 100) : 0
                onReleased: (v) => {
                    p.setDock("Magnification", v > 2 ? "true" : "false")
                    if (v > 2) p.setDock("MagnificationSize", String(Math.round(64 + v / 100 * 64)))
                }
            }
            Txt { text: "Máx."; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
        RowItem {
            title: "Posición en la pantalla"
            MacPopup {
                readonly property var vals: ["left", "bottom", "right"]
                model: ["Izquierda", "Abajo", "Derecha"]
                currentIndex: p.idx(vals, p.dockConf("Position", "bottom"), 1)
                onActivated: (i) => p.setDock("Position", vals[i])
            }
        }
        RowItem {
            title: "Minimizar ventanas usando"
            MacPopup {
                model: ["Efecto de escala", "Efecto lámpara mágica", "Ninguno"]
                currentIndex: p.kwinConf("Plugins", "magiclampEnabled", "false") === "true" ? 1 : (p.kwinConf("Plugins", "squashEnabled", "true") === "true" ? 0 : 2)
                onActivated: (i) => {
                    Sys.writeConf("kwinrc", ["Plugins"], "squashEnabled", i === 0 ? "true" : "false")
                    p.kwin("Plugins", "magiclampEnabled", i === 1 ? "true" : "false")
                }
            }
        }
        RowItem {
            title: "Hacer doble clic en la barra de título de una ventana para"
            MacPopup {
                readonly property var vals: ["Maximize", "Minimize", "Nothing"]
                model: ["Acercar", "Minimizar", "No hacer nada"]
                currentIndex: p.idx(vals, p.kwinConf("Windows", "TitlebarDoubleClickCommand", "Maximize"))
                onActivated: (i) => p.kwin("Windows", "TitlebarDoubleClickCommand", vals[i])
            }
        }
        RowItem {
            title: "Botones de la vista previa"
            subtitle: "Cerrar, minimizar y maximizar cada ventana al pasar el puntero por su miniatura"
            MacPopup {
                readonly property var vals: ["abajo", "arriba"]
                model: ["Abajo", "Arriba"]
                currentIndex: Math.max(0, vals.indexOf(p.dockConf("PreviewButtons", "abajo")))
                onActivated: (i) => p.setDock("PreviewButtons", vals[i])
            }
        }
        RowItem {
            title: "Ocultar y mostrar el Dock automáticamente"
            MacSwitch {
                checked: p.dockConf("Autohide", "false") === "true"
                onToggled: (v) => p.setDock("Autohide", v ? "true" : "false")
            }
        }
        RowItem {
            title: "Ocultar el Dock con ventanas maximizadas"
            subtitle: "Se aparta de las ventanas maximizadas o a pantalla completa; lleva el puntero al borde para verlo"
            MacSwitch {
                checked: p.dockConf("HideOnMaximize", "true") === "true"
                onToggled: (v) => p.setDock("HideOnMaximize", v ? "true" : "false")
            }
        }
        RowItem {
            title: "Animar la apertura de aplicaciones"
            MacSwitch {
                checked: p.dockConf("Bounce", "true") === "true"
                onToggled: (v) => p.setDock("Bounce", v ? "true" : "false")
            }
        }
        RowItem {
            title: "Mostrar indicadores de las apps abiertas"
            MacSwitch {
                checked: p.dockConf("ShowIndicators", "true") === "true"
                onToggled: (v) => p.setDock("ShowIndicators", v ? "true" : "false")
            }
        }
    }
    Note { text: "Para añadir o quitar apps del Dock, haz clic derecho sobre su icono." }

    SectionHeader { text: "Ventanas" }
    Card {
        RowItem {
            title: "Arrastrar ventanas a los bordes de la pantalla para organizarlas en mosaico"
            MacSwitch {
                checked: p.kwinConf("Windows", "ElectricBorderTiling", "true") === "true"
                onToggled: (v) => p.kwin("Windows", "ElectricBorderTiling", v ? "true" : "false")
            }
        }
        RowItem {
            title: "Arrastrar ventanas a la barra de menús para llenar la pantalla"
            MacSwitch {
                checked: p.kwinConf("Windows", "ElectricBorderMaximize", "true") === "true"
                onToggled: (v) => p.kwin("Windows", "ElectricBorderMaximize", v ? "true" : "false")
            }
        }
        RowItem {
            title: "Atraer las ventanas a los bordes y a otras ventanas"
            subtitle: "Al moverlas, se ajustan a bordes cercanos"
            MacSwitch {
                checked: Number(p.kwinConf("Windows", "BorderSnapZone", "10")) > 0
                onToggled: (v) => {
                    Sys.writeConf("kwinrc", ["Windows"], "WindowSnapZone", v ? "10" : "0")
                    p.kwin("Windows", "BorderSnapZone", v ? "10" : "0")
                }
            }
        }
        RowItem {
            title: "Activar las ventanas al pasar el ratón"
            subtitle: "El foco sigue al cursor (opción de KDE)"
            MacSwitch {
                checked: p.kwinConf("Windows", "FocusPolicy", "ClickToFocus") !== "ClickToFocus"
                onToggled: (v) => p.kwin("Windows", "FocusPolicy", v ? "FocusFollowsMouse" : "ClickToFocus")
            }
        }
    }

    SectionHeader { text: "Mission Control" }
    Card {
        RowItem {
            title: "Cambiar de escritorio al llevar una ventana al borde"
            subtitle: "Al arrastrar una ventana hasta el borde de la pantalla"
            MacSwitch {
                checked: p.kwinConf("Windows", "ElectricBorders", "0") !== "0"
                onToggled: (v) => p.kwin("Windows", "ElectricBorders", v ? "1" : "0")
            }
        }
    }
    // Esquinas activas: como en macOS, un botón al pie de Escritorio y Dock que abre la hoja de esquinas
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        MacButton {
            text: "Esquinas activas…"
            onClicked: { hotCorners.rev++; hotCorners.open() }
        }
    }
    HotCorners { id: hotCorners }

    KdeOptions {
        page: p
        items: [
            { t: "Escritorios virtuales", s: "Spaces: cantidad, nombres y animación", k: "kcm_kwin_virtualdesktops", icon: "virtual-desktops-symbolic" },
            { t: "Comportamiento de las ventanas", s: "Foco, colocación y acciones del ratón", k: "kcm_kwinoptions", icon: "preferences-system-windows-behavior-symbolic" },
            { t: "Cambiador de ventanas (Alt+Tab)", k: "kcm_kwintabbox", icon: "preferences-system-tabbox-symbolic" },
            { t: "Bordes de la pantalla", s: "Esquinas y bordes con más acciones", k: "kcm_kwinscreenedges", icon: "preferences-desktop-screen-edges-symbolic" },
            { t: "Reglas de ventanas", s: "Tamaño, posición y comportamiento por app", k: "kcm_kwinrules", icon: "preferences-system-windows-actions-symbolic" },
            { t: "Scripts de KWin", k: "kcm_kwin_scripts", icon: "preferences-system-windows-script-symbolic" },
            { t: "Atajos de teclado", k: "kcm_keys", icon: "input-keyboard-symbolic" }
        ]
    }
}
