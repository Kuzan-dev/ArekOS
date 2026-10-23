import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Page {
    id: p
    title: "Información"
    function osr(key) {
        const m = Sys.readFile("/etc/os-release").match(new RegExp("^" + key + "=\"?([^\"\\n]*)", "m"))
        return m ? m[1] : ""
    }
    readonly property string cpu: (Sys.readFile("/proc/cpuinfo").match(/model name\s*:\s*(.*)/) || ["", "—"])[1]
    readonly property string gpu: {
        const l = Sys.run("lspci").split("\n").filter(x => /VGA|3D controller/.test(x)).map(x => x.replace(/^.*?: /, "").replace(/\(rev.*\)/, "").trim())
        return l.join("\n") || "—"
    }
    readonly property string mem: {
        const kb = Number((Sys.readFile("/proc/meminfo").match(/MemTotal:\s*(\d+)/) || [0, 0])[1])
        return Math.round(kb / 1048576) + " GB"
    }
    readonly property var disk: Sys.run("df", ["-B1", "--output=size,used", "/"]).trim().split("\n")[1].trim().split(/\s+/).map(Number)
    function gb(b) { return (b / 1e9).toFixed(b > 1e11 ? 0 : 1) + " GB" }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 6
        Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; source: "fedora-logo-icon"; fallback: "distributor-logo"; implicitWidth: 84; implicitHeight: 84 }
        Txt { Layout.alignment: Qt.AlignHCenter; text: p.osr("NAME"); font.pixelSize: 26; font.weight: Font.DemiBold }
        Txt { Layout.alignment: Qt.AlignHCenter; text: "Versión " + p.osr("VERSION_ID") + " · KDE Plasma " + Sys.run("plasmashell", ["--version"]).replace(/[^0-9.]/g, ""); color: Theme.secondary }
        Item { Layout.preferredHeight: 6 }
    }
    Card {
        RowItem { title: "Nombre"; Txt { text: Sys.run("hostname").trim(); color: Theme.secondary } }
        RowItem { title: "Procesador"; Txt { text: p.cpu; color: Theme.secondary } }
        RowItem { title: "Gráficos"; Txt { text: p.gpu; color: Theme.secondary; horizontalAlignment: Text.AlignRight } }
        RowItem { title: "Memoria"; Txt { text: p.mem; color: Theme.secondary } }
        RowItem { title: "Núcleo"; Txt { text: Sys.run("uname", ["-r"]).trim(); color: Theme.secondary } }
    }
    SectionHeader { text: "Almacenamiento" }
    Card {
        RowItem {
            title: "Disco del sistema"
            subtitle: p.gb(p.disk[0] - p.disk[1]) + " disponibles de " + p.gb(p.disk[0])
            Rectangle {
                width: 160; height: 8; radius: 4; color: Theme.switchOff
                Rectangle { width: parent.width * p.disk[1] / p.disk[0]; height: parent.height; radius: 4; color: Theme.accent }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        MacButton { text: "Informe del sistema…"; onClicked: Sys.detached("kinfocenter") }
    }
}
