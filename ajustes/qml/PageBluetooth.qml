import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Bluetooth"
    property bool hasAdapter: false
    property bool powered: false
    property var devices: []
    // bluetoothctl se queda esperando si no hay adaptador: siempre con límite de tiempo
    function bt(args) { return Sys.run("timeout", ["3", "bluetoothctl"].concat(args), 4000) }
    function refresh() {
        hasAdapter = Sys.listDir("/sys/class/bluetooth", [], true).length > 0
        if (!hasAdapter) return
        powered = /Powered: yes/.test(bt(["show"]))
        const list = []
        for (const line of bt(["devices", "Paired"]).split("\n")) {
            const m = line.match(/^Device ([0-9A-F:]{17}) (.*)$/)
            if (!m) continue
            list.push({ mac: m[1], name: m[2], connected: /Connected: yes/.test(bt(["info", m[1]])) })
        }
        devices = list
    }
    Component.onCompleted: refresh()

    Card {
        RowItem {
            title: "Bluetooth"
            tileIcon: "network-bluetooth-symbolic"
            subtitle: p.hasAdapter ? (p.powered ? "Visible como «" + Sys.run("hostname").trim() + "»" : "") : "No se ha encontrado ningún adaptador Bluetooth"
            MacSwitch { enabled2: p.hasAdapter; checked: p.powered; onToggled: (v) => { p.bt(["power", v ? "on" : "off"]); p.refresh() } }
        }
    }
    SectionHeader { text: "Mis dispositivos"; visible: p.devices.length > 0 }
    Card {
        visible: p.devices.length > 0
        Repeater {
            model: p.devices
            RowItem {
                title: modelData.name
                subtitle: modelData.connected ? "Conectado" : "No conectado"
                MacButton {
                    text: modelData.connected ? "Desconectar" : "Conectar"
                    onClicked: { p.bt([modelData.connected ? "disconnect" : "connect", modelData.mac]); p.refresh() }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: p.hasAdapter
        Item { Layout.fillWidth: true }
        MacButton { text: "Añadir dispositivo…"; onClicked: p.kcm("kcm_bluetooth") }
    }
}
