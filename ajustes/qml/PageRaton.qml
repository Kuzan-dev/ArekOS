import QtQuick
import QtQuick.Layouts

// Ratón y trackpad (macOS: Ratón / Trackpad). Los valores se aplican al momento a través de KWin,
// que los guarda por dispositivo; las opciones completas de KDE quedan al final.
Page {
    id: p
    title: "Ratón y trackpad"
    property var devs: []
    function refresh() {
        devs = Sys.run(Sys.home() + "/.local/bin/vitrum-raton", [], 5000).split("\n").filter(l => l.indexOf("|") > 0).map(l => {
            const f = l.split("|")
            return { sys: f[0], name: f[1], touchpad: f[3] === "true", accel: Number(f[4]), natural: f[5] === "true", left: f[6] === "true",
                     tap: f[7] === "true", typing: f[8] === "true", scroll: Number(f[9]), fingers: f[10] === "true", flat: f[11] === "true" }
        })
    }
    Component.onCompleted: refresh()
    readonly property var mouse: devs.find(d => !d.touchpad) || null
    readonly property var pad: devs.find(d => d.touchpad) || null
    function set(kind, prop, type, value) { Sys.runAsync("raton", Sys.home() + "/.local/bin/vitrum-raton", ["set", kind, prop, type, String(value)]) }
    Connections { target: Sys; function onFinished(tag) { if (tag === "raton") p.refresh() } }

    SectionHeader { text: "Ratón" }
    Card {
        RowItem { visible: !p.mouse; title: "No se ha encontrado ningún ratón"; dimmed: true }
        RowItem {
            visible: !!p.mouse
            title: "Velocidad del puntero"
            Txt { text: "Lenta"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider { width: 170; from: -1; to: 1; stepSize: 0.05; value: p.mouse ? p.mouse.accel : 0; onReleased: (v) => p.set("raton", "pointerAcceleration", "d", v.toFixed(2)) }
            Txt { text: "Rápida"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
        RowItem {
            visible: !!p.mouse
            title: "Desplazamiento natural"
            subtitle: "El contenido sigue el movimiento de la rueda"
            MacSwitch { checked: p.mouse ? p.mouse.natural : false; onToggled: (v) => p.set("raton", "naturalScroll", "b", v) }
        }
        RowItem {
            visible: !!p.mouse
            title: "Velocidad de desplazamiento"
            Txt { text: "Lenta"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider { width: 170; from: 0.2; to: 3; stepSize: 0.1; value: p.mouse ? p.mouse.scroll : 1; onReleased: (v) => p.set("raton", "scrollFactor", "d", v.toFixed(1)) }
            Txt { text: "Rápida"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
        RowItem {
            visible: !!p.mouse
            title: "Botón principal"
            MacPopup { model: ["Izquierdo", "Derecho"]; currentIndex: p.mouse && p.mouse.left ? 1 : 0; onActivated: (i) => p.set("raton", "leftHanded", "b", i === 1) }
        }
        RowItem {
            visible: !!p.mouse
            title: "Aceleración del puntero"
            subtitle: "Desactívala para un movimiento constante (juegos)"
            MacSwitch { checked: p.mouse ? !p.mouse.flat : true; onToggled: (v) => { p.set("raton", "pointerAccelerationProfileFlat", "b", !v); p.set("raton", "pointerAccelerationProfileAdaptive", "b", v) } }
        }
        RowItem {
            title: "Velocidad del doble clic"
            Txt { text: "Lenta"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider {
                width: 170; from: 800; to: 200; stepSize: 25
                value: Number(Sys.readConf("kdeglobals", ["KDE"], "DoubleClickInterval", "400"))
                onReleased: (v) => Sys.writeConf("kdeglobals", ["KDE"], "DoubleClickInterval", String(Math.round(v)))
            }
            Txt { text: "Rápida"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
    }

    SectionHeader { text: "Trackpad"; visible: !!p.pad }
    Card {
        visible: !!p.pad
        RowItem {
            title: "Velocidad del puntero"
            Txt { text: "Lenta"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider { width: 170; from: -1; to: 1; stepSize: 0.05; value: p.pad ? p.pad.accel : 0; onReleased: (v) => p.set("trackpad", "pointerAcceleration", "d", v.toFixed(2)) }
            Txt { text: "Rápida"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
        RowItem {
            title: "Tocar para hacer clic"
            MacSwitch { checked: p.pad ? p.pad.tap : false; onToggled: (v) => p.set("trackpad", "tapToClick", "b", v) }
        }
        RowItem {
            title: "Clic secundario"
            MacPopup {
                model: ["Hacer clic con dos dedos", "Clic en la esquina inferior derecha"]
                currentIndex: p.pad && !p.pad.fingers ? 1 : 0
                onActivated: (i) => { p.set("trackpad", "clickMethodClickfinger", "b", i === 0); p.set("trackpad", "clickMethodAreas", "b", i === 1) }
            }
        }
        RowItem {
            title: "Desplazamiento natural"
            MacSwitch { checked: p.pad ? p.pad.natural : true; onToggled: (v) => p.set("trackpad", "naturalScroll", "b", v) }
        }
        RowItem {
            title: "Ignorar el trackpad mientras escribes"
            MacSwitch { checked: p.pad ? p.pad.typing : true; onToggled: (v) => p.set("trackpad", "disableWhileTyping", "b", v) }
        }
    }

    KdeOptions {
        page: p
        items: [
            { t: "Ratón", s: "Todas las opciones por dispositivo", k: "kcm_mouse", icon: "input-mouse-symbolic" },
            { t: "Panel táctil", k: "kcm_touchpad", icon: "input-touchpad-symbolic" },
            { t: "Tableta gráfica", k: "kcm_tablet", icon: "input-tablet-symbolic" },
            { t: "Pantalla táctil", k: "kcm_touchscreen", icon: "input-touchscreen-symbolic" },
            { t: "Mandos de juego", k: "kcm_gamecontroller", icon: "input-gamepad-symbolic" }
        ]
    }
}
