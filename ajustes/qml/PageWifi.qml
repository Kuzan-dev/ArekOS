import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Wi‑Fi"
    property bool hasDevice: false
    property bool wifiOn: false
    property string connected: ""
    property var known: []
    property var networks: []
    property bool scanning: false
    property string status: ""

    function nm(args) { return Sys.run("nmcli", args) }
    function parse(line) { return line.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":")) }
    function refresh() {
        hasDevice = nm(["-t", "-f", "TYPE", "device"]).split("\n").indexOf("wifi") >= 0
        wifiOn = nm(["-t", "-f", "WIFI", "general"]).trim() === "enabled"
        known = nm(["-t", "-f", "NAME,TYPE", "connection", "show"]).split("\n").map(parse)
            .filter(f => f[1] === "802-11-wireless").map(f => f[0])
        if (hasDevice && wifiOn) { scanning = true; Sys.runAsync("wifi-scan", "nmcli", ["-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]) }
    }
    function bars(sig) { return sig > 75 ? "▂▄▆█" : sig > 50 ? "▂▄▆" : sig > 25 ? "▂▄" : "▂" }
    function connect(n) {
        status = "Conectando a " + n.ssid + "…"
        if (known.indexOf(n.ssid) >= 0 || !n.secure) Sys.runAsync("wifi-con", "nmcli", ["device", "wifi", "connect", n.ssid])
        else { pass.heading = "La red Wi‑Fi «" + n.ssid + "» requiere una contraseña."; pass.target = n.ssid; pass.open() }
    }
    Connections {
        target: Sys
        function onFinished(tag, code, out, err) {
            if (tag === "wifi-scan") {
                p.scanning = false
                const seen = {}
                const list = []
                for (const line of out.split("\n")) {
                    if (!line) continue
                    const f = p.parse(line)
                    if (!f[1] || seen[f[1]]) continue
                    seen[f[1]] = true
                    if (f[0] === "*") p.connected = f[1]
                    list.push({ ssid: f[1], signal: Number(f[2]), secure: f[3] !== "" && f[3] !== "--", inUse: f[0] === "*" })
                }
                p.networks = list
            } else if (tag === "wifi-con") {
                p.status = code === 0 ? "" : "No se pudo conectar: " + (err || out).trim()
                p.refresh()
            }
        }
    }
    Component.onCompleted: refresh()

    Sheet {
        id: pass
        property string target: ""
        placeholder: "Contraseña"
        onAccepted: (v) => Sys.runAsync("wifi-con", "nmcli", ["device", "wifi", "connect", target, "password", v])
    }

    Card {
        RowItem {
            title: "Wi‑Fi"
            tileIcon: "network-wireless-symbolic"
            subtitle: !p.hasDevice ? "No se ha encontrado ningún adaptador Wi‑Fi" : (p.connected ? "Conectado a " + p.connected : "")
            MacSwitch {
                enabled2: p.hasDevice
                checked: p.wifiOn
                onToggled: (v) => { Sys.run("nmcli", ["radio", "wifi", v ? "on" : "off"]); p.connected = ""; p.networks = []; Qt.callLater(p.refresh) }
            }
        }
    }
    Note { visible: p.status !== ""; text: p.status }

    SectionHeader { text: "Redes conocidas"; visible: p.known.length > 0 }
    Card {
        visible: p.known.length > 0
        Repeater {
            model: p.known
            RowItem {
                title: modelData
                subtitle: modelData === p.connected ? "Conectada" : ""
                MacButton {
                    text: "Olvidar"
                    onClicked: { Sys.run("nmcli", ["connection", "delete", "id", modelData]); p.refresh() }
                }
            }
        }
    }

    SectionHeader { text: p.scanning ? "Buscando redes…" : "Otras redes"; visible: p.hasDevice && p.wifiOn }
    Card {
        visible: p.networks.length > 0
        Repeater {
            model: p.networks
            RowItem {
                title: modelData.ssid
                chevron: false
                Txt { visible: modelData.inUse; text: "✓"; color: Theme.accent }
                Txt { visible: modelData.secure; text: "🔒"; font.pixelSize: 11; color: Theme.secondary }
                Txt { text: p.bars(modelData.signal); color: Theme.secondary; font.pixelSize: 11 }
                MacButton { visible: !modelData.inUse; text: "Conectar"; onClicked: p.connect(modelData) }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        MacButton { text: "Avanzado…"; onClicked: p.kcm("kcm_networkmanagement") }
    }
}
