import QtQuick
import QtQuick.Layouts

// Bluetooth, como en macOS: «Mis dispositivos» (emparejados: conectar, desconectar, olvidar) y «Dispositivos
// cercanos», que se buscan mientras la página está abierta; «Conectar» empareja y conecta en un paso.
// Todo pasa por vitrum-bt (BlueZ por D-Bus) en segundo plano, para que la ventana no se congele.
Page {
    id: p
    title: "Bluetooth"
    readonly property string helper: Sys.home() + "/.local/bin/vitrum-bt"
    property bool hasAdapter: false
    property bool powered: false
    property var mine: []
    property var nearby: []
    property var busy: ({})          // mac → texto («Conectando…»)
    property var errors: ({})        // mac → error del último intento
    property bool scanning: false
    property string alias: ""        // nombre con el que otros dispositivos ven este equipo

    function refreshPower() {
        hasAdapter = Sys.listDir("/sys/class/bluetooth", [], true).length > 0
        if (hasAdapter) Sys.runAsync("bt-show", "timeout", ["3", "bluetoothctl", "show"])
    }
    function parse(out) {
        const m = [], n = []
        for (const l of out.split("\n")) {
            const f = l.split("|")
            if (f.length < 6) continue
            const d = { mac: f[0], name: f[1], paired: f[2] === "1", connected: f[3] === "1", icon: f[4], rssi: Number(f[5] || -999) }
            ;(d.paired ? m : n).push(d)
        }
        mine = m
        nearby = n.sort((a, b) => b.rssi - a.rssi)
    }
    function list() { Sys.runAsync("bt-list", helper, ["list"]) }
    function scan() { if (powered && !scanning) { scanning = true; Sys.runAsync("bt-scan", helper, ["scan", "8"]) } }
    function act(cmd, mac, label) {
        const b = Object.assign({}, busy); b[mac] = label; busy = b
        const e = Object.assign({}, errors); delete e[mac]; errors = e
        Sys.runAsync("bt-act|" + mac, helper, [cmd, mac])
    }
    function iconFor(i) {
        return i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0 ? "audio-headphones-symbolic"
             : i.indexOf("audio") >= 0 ? "audio-speakers-symbolic"
             : i.indexOf("mouse") >= 0 ? "input-mouse-symbolic"
             : i.indexOf("keyboard") >= 0 ? "input-keyboard-symbolic"
             : i.indexOf("phone") >= 0 ? "smartphone-symbolic"
             : i.indexOf("computer") >= 0 ? "computer-symbolic"
             : i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0 ? "input-gaming-symbolic"
             : "network-bluetooth-symbolic"
    }
    Connections {
        target: Sys
        function onFinished(tag, code, out) {
            if (tag === "bt-show") {
                p.powered = /Powered: yes/.test(out)
                const a = out.match(/^\s*Alias: (.+)$/m); p.alias = a ? a[1].trim() : ""
                p.list(); p.scan()
            }
            else if (tag === "bt-list") p.parse(out)
            else if (tag === "bt-scan") { p.scanning = false; p.parse(out); rescan.restart() }
            else if (tag.indexOf("bt-act|") === 0) {
                const mac = tag.slice(7)
                const b = Object.assign({}, p.busy); delete b[mac]; p.busy = b
                const err = out.split("\n").find(l => l.indexOf("error|") === 0)
                if (err) { const e = Object.assign({}, p.errors); e[mac] = err.slice(6); p.errors = e }
                p.list()
            }
        }
    }
    // mientras la página está abierta se sigue buscando (como macOS)
    Timer { id: rescan; interval: 2500; onTriggered: p.scan() }
    // el estado de conexión puede cambiar desde fuera (el dispositivo se apaga, el Centro de Control…)
    Timer { interval: 4000; running: p.powered; repeat: true; onTriggered: if (!Object.keys(p.busy).length) p.list() }
    Component.onCompleted: refreshPower()

    Card {
        RowItem {
            title: "Bluetooth"
            tileIcon: "network-bluetooth-symbolic"
            subtitle: p.hasAdapter ? (p.powered && p.alias ? "Visible como «" + p.alias + "»" : "") : "No se ha encontrado ningún adaptador Bluetooth"
            MacSwitch {
                enabled2: p.hasAdapter; checked: p.powered
                onToggled: (v) => { Sys.runAsync("bt-power", p.helper, ["power", v ? "on" : "off"]); p.powered = v; if (v) p.scan(); else { p.nearby = [] } }
            }
        }
    }

    SectionHeader { text: "Mis dispositivos"; visible: p.powered && p.mine.length > 0 }
    Card {
        visible: p.powered && p.mine.length > 0
        Repeater {
            model: p.mine
            RowItem {
                title: modelData.name
                tileIcon: p.iconFor(modelData.icon)
                tileColor: Theme.tile.blue
                subtitle: p.errors[modelData.mac] ? p.errors[modelData.mac]
                        : p.busy[modelData.mac] ? p.busy[modelData.mac] : (modelData.connected ? "Conectado" : "No conectado")
                MacButton {
                    visible: !p.busy[modelData.mac]
                    text: modelData.connected ? "Desconectar" : "Conectar"
                    onClicked: p.act(modelData.connected ? "disconnect" : "connect", modelData.mac, modelData.connected ? "Desconectando…" : "Conectando…")
                }
                MacButton {
                    visible: !p.busy[modelData.mac]
                    text: "Olvidar"
                    onClicked: p.act("remove", modelData.mac, "Olvidando…")
                }
            }
        }
    }

    SectionHeader { text: "Dispositivos cercanos"; visible: p.powered }
    Card {
        visible: p.powered
        RowItem {
            visible: p.nearby.length === 0
            title: p.scanning ? "Buscando dispositivos…" : "No se han encontrado dispositivos"
            subtitle: "Pon el dispositivo en modo de emparejamiento"
        }
        Repeater {
            model: p.nearby
            RowItem {
                title: modelData.name
                tileIcon: p.iconFor(modelData.icon)
                tileColor: Theme.tile.grey
                subtitle: p.errors[modelData.mac] ? p.errors[modelData.mac] : (p.busy[modelData.mac] || "")
                MacButton {
                    visible: !p.busy[modelData.mac]
                    text: "Conectar"
                    onClicked: p.act("pair", modelData.mac, "Conectando…")
                }
            }
        }
    }

    KdeOptions {
        page: p
        items: [
            { t: "Bluetooth de KDE", s: "Opciones avanzadas, transferencia de archivos", k: "kcm_bluetooth", icon: "network-bluetooth-symbolic" }
        ]
    }
}
