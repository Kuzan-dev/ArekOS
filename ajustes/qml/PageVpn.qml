import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "VPN"
    property var vpns: []
    function refresh() {
        vpns = Sys.run("nmcli", ["-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]).split("\n")
            .map(l => l.split(":")).filter(f => f[1] === "vpn" || f[1] === "wireguard")
            .map(f => ({ name: f[0], type: f[1], active: f[2] === "yes" }))
    }
    Component.onCompleted: refresh()

    Card {
        RowItem {
            visible: p.vpns.length === 0
            title: "No hay configuraciones VPN"
            subtitle: "Añade una conexión VPN o WireGuard para verla aquí."
        }
        Repeater {
            model: p.vpns
            RowItem {
                title: modelData.name
                subtitle: (modelData.type === "wireguard" ? "WireGuard" : "VPN") + (modelData.active ? " · Conectada" : "")
                tileIcon: "network-vpn-symbolic"
                MacSwitch {
                    checked: modelData.active
                    onToggled: (v) => { Sys.runAsync("vpn", "nmcli", ["connection", v ? "up" : "down", "id", modelData.name]) }
                }
            }
        }
    }
    Connections { target: Sys; function onFinished(tag) { if (tag === "vpn") p.refresh() } }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        MacButton { text: "Añadir configuración VPN…"; onClicked: p.kcm("kcm_networkmanagement") }
    }
}
