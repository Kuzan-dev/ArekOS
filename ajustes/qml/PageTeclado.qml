import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Teclado"
    function r(k, d) { return Sys.readConf("kcminputrc", ["Keyboard"], k, d) }
    function w(k, v) {
        Sys.writeConf("kcminputrc", ["Keyboard"], k, v)
        Sys.detached("dbus-send", ["--session", "--type=signal", "/Layouts", "org.kde.keyboard.reloadConfig"])
    }
    Card {
        RowItem {
            title: "Velocidad de repetición"
            Txt { text: "Lenta"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider { width: 170; from: 5; to: 60; stepSize: 1; value: Number(p.r("RepeatRate", "25")); onReleased: (v) => p.w("RepeatRate", String(Math.round(v))) }
            Txt { text: "Rápida"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
        RowItem {
            title: "Retardo hasta repetir"
            Txt { text: "Largo"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider { width: 170; from: 900; to: 150; stepSize: 25; value: Number(p.r("RepeatDelay", "600")); onReleased: (v) => p.w("RepeatDelay", String(Math.round(v))) }
            Txt { text: "Corto"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
        RowItem {
            title: "Bloq Num al iniciar sesión"
            MacPopup {
                model: ["Activado", "Desactivado", "Sin cambios"]
                currentIndex: Number(p.r("NumLock", "2"))
                onActivated: (i) => p.w("NumLock", String(i))
            }
        }
    }
    // macOS: Atajos de teclado… / Fuentes de entrada: Editar… / Texto (corrección)
    Card {
        RowItem { title: "Atajos de teclado"; subtitle: "Ctrl+C, Super, Alt+Espacio y el resto"; tileIcon: "input-keyboard-symbolic"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.kcm("kcm_keys") }
        RowItem { title: "Fuentes de entrada"; subtitle: "Distribuciones de teclado e idiomas"; tileIcon: "map-globe-symbolic"; tileColor: Theme.tile.blue; chevron: true; onClicked: p.kcm("kcm_keyboard") }
        RowItem { title: "Corrección ortográfica"; tileIcon: "tools-check-spelling-symbolic"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.kcm("kcmspellchecking") }
    }
    KdeOptions {
        page: p
        items: [
            { t: "Teclado en pantalla", k: "kcm_virtualkeyboard", icon: "input-keyboard-virtual-symbolic" },
            { t: "Teclado de Plasma", s: "Teclado táctil de Plasma", k: "kcm_plasmakeyboard", icon: "input-keyboard-symbolic" }
        ]
    }
}
