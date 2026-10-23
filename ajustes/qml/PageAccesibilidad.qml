import QtQuick
import QtQuick.Layouts

// Accesibilidad (macOS Sequoia: Visión → Pantalla, Zoom, VoiceOver; Movilidad → Teclado, Puntero).
Page {
    id: p
    title: "Accesibilidad"
    function kw(group, key, value) { Sys.writeConf("kwinrc", [group], key, value); p.kwinReconfigure() }
    function plugin(name, def) { return Sys.readConf("kwinrc", ["Plugins"], name + "Enabled", def) === "true" }

    SectionHeader { text: "Visión" }
    Card {
        RowItem {
            title: "Reducir el movimiento"
            subtitle: "Desactiva las animaciones del escritorio y de las apps"
            MacSwitch {
                checked: Number(Sys.readConf("kdeglobals", ["KDE"], "AnimationDurationFactor", "1")) === 0
                onToggled: (v) => Sys.writeConf("kdeglobals", ["KDE"], "AnimationDurationFactor", v ? "0" : "1")
            }
        }
        RowItem {
            title: "Reducir la transparencia"
            subtitle: "Barra de menús, menús, dock y barras laterales opacos, sin desenfoque"
            MacSwitch {
                checked: !p.plugin("blur", "true")
                onToggled: (v) => {
                    Sys.writeConf("kwinrc", ["Plugins"], "contrastEnabled", v ? "false" : "true")
                    Sys.writeConf("darklyrc", ["Style"], "MenuOpacity", v ? "100" : "55")
                    Sys.writeConf("darklyrc", ["Style"], "DolphinSidebarOpacity", v ? "100" : "78")
                    p.kw("Plugins", "blurEnabled", v ? "false" : "true")
                }
            }
        }
        RowItem {
            title: "Zoom con el teclado"
            subtitle: "Super + = para acercar, Super + − para alejar, Super + 0 para volver"
            MacSwitch { checked: p.plugin("zoom", "true"); onToggled: (v) => p.kw("Plugins", "zoomEnabled", v ? "true" : "false") }
        }
        RowItem {
            title: "Lector de pantalla"
            subtitle: "Orca lee en voz alta lo que hay en pantalla (como VoiceOver)"
            MacSwitch {
                checked: Sys.readConf("kaccessrc", ["ScreenReader"], "Enabled", "false") === "true"
                onToggled: (v) => { Sys.writeConf("kaccessrc", ["ScreenReader"], "Enabled", v ? "true" : "false"); if (v) Sys.detached("orca") }
            }
        }
    }
    SectionHeader { text: "Puntero" }
    Card {
        RowItem {
            title: "Tamaño del puntero"
            MacPopup {
                readonly property var vals: ["24", "32", "48", "64"]
                model: ["Normal", "Grande", "Muy grande", "Enorme"]
                currentIndex: p.idx(vals, Sys.readConf("kcminputrc", ["Mouse"], "cursorSize", "24"))
                onActivated: (i) => {
                    Sys.writeConf("kcminputrc", ["Mouse"], "cursorSize", vals[i])
                    Sys.detached("plasma-apply-cursortheme", [Sys.readConf("kcminputrc", ["Mouse"], "cursorTheme", "breeze_cursors"), "--size", vals[i]])
                }
            }
        }
        RowItem {
            title: "Sacudir el puntero para localizarlo"
            MacSwitch { checked: p.plugin("shakecursor", "true"); onToggled: (v) => p.kw("Plugins", "shakecursorEnabled", v ? "true" : "false") }
        }
    }
    KdeOptions {
        page: p
        items: [
            { t: "Accesibilidad de KDE", s: "Teclas lentas y especiales, timbre visual, filtros de color, zoom", k: "kcm_access", icon: "preferences-desktop-accessibility-symbolic" },
            { t: "Teclado en pantalla", k: "kcm_virtualkeyboard", icon: "input-keyboard-virtual-symbolic" }
        ]
    }
}
