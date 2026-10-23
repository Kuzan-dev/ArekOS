import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Red"
    property var devices: []
    readonly property var typeNames: ({ ethernet: "Ethernet", wifi: "Wi‑Fi", bridge: "Puente", wireguard: "WireGuard", tun: "Túnel", bt: "Bluetooth" })
    function refresh() {
        const list = []
        for (const line of Sys.run("nmcli", ["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]).split("\n")) {
            const f = line.split(":")
            if (f.length < 4 || f[1] === "loopback" || f[1] === "wifi-p2p") continue
            const info = Sys.run("nmcli", ["-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", f[0]])
            const get = (k) => (info.split("\n").find(l => l.indexOf(k) === 0) || "").split(":").slice(1).join(":")
            list.push({ dev: f[0], type: f[1], up: f[2].indexOf("connected") === 0 && f[2].indexOf("dis") < 0,
                        conn: f[3], ip: get("IP4.ADDRESS"), gw: get("IP4.GATEWAY"), dns: get("IP4.DNS") })
        }
        devices = list
    }
    Component.onCompleted: refresh()

    Card {
        Repeater {
            model: p.devices
            RowItem {
                title: (p.typeNames[modelData.type] || modelData.type) + "  ·  " + modelData.dev
                subtitle: modelData.up ? "Conectado" + (modelData.ip ? " — IP " + modelData.ip.split("/")[0] : "") : "No conectado"
                tileIcon: modelData.type === "wifi" ? "network-wireless-symbolic" : "network-wired-symbolic"
                tileColor: modelData.up ? Theme.tile.blue : Theme.tile.grey
                Rectangle { width: 8; height: 8; radius: 4; color: modelData.up ? "#30C759" : "#FF3B30"; anchors.verticalCenter: parent ? parent.verticalCenter : undefined }
            }
        }
    }
    SectionHeader { text: "Detalles"; visible: p.devices.some(d => d.up) }
    Card {
        visible: p.devices.some(d => d.up)
        Repeater {
            model: p.devices.filter(d => d.up)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowItem { title: "Dirección IP"; Txt { text: modelData.ip.split("/")[0] || "—"; color: Theme.secondary } }
                RowItem { title: "Router"; Txt { text: modelData.gw || "—"; color: Theme.secondary } }
                RowItem { title: "Servidores DNS"; Txt { text: modelData.dns || "—"; color: Theme.secondary } }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        MacButton { text: "Proxies…"; onClicked: p.kcm("kcm_proxy") }
        MacButton { text: "Avanzado…"; onClicked: p.kcm("kcm_networkmanagement") }
    }
}
