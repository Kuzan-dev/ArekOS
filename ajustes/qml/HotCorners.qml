import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

// Esquinas activas, como en macOS (Escritorio y Dock → Esquinas activas…): una pantalla dibujada con un
// desplegable en cada esquina. KWin: [ElectricBorders] para las acciones del sistema y las listas BorderActivate
// de los efectos (vista general = Mission Control; vista de ventanas = todas o las de la app). Índices de
// esquina de KWin: 1 arriba-dcha, 3 abajo-dcha, 5 abajo-izda, 7 arriba-izda (9 = ninguna).
QQC.Popup {
    id: hc
    parent: QQC.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    padding: 22
    readonly property var acts: ["None", "Overview", "AllWindows", "AppWindows", "ShowDesktop", "LockScreen"]
    readonly property var labels: ["—", "Mission Control", "Todas las ventanas", "Ventanas de la app", "Escritorio", "Bloquear pantalla"]
    property int rev: 0

    function lst(group, key) {
        return Sys.readConf("kwinrc", [group], key, "9").split(",").map(Number).filter(x => x !== 9 && !isNaN(x))
    }
    function action(key, i) {
        rev
        if (lst("Effect-overview", "BorderActivate").indexOf(i) >= 0) return 1
        if (lst("Effect-windowview", "BorderActivateAll").indexOf(i) >= 0) return 2
        if (lst("Effect-windowview", "BorderActivateClass").indexOf(i) >= 0) return 3
        const a = Sys.readConf("kwinrc", ["ElectricBorders"], key, "None")
        return a === "ShowDesktop" ? 4 : a === "LockScreen" ? 5 : 0
    }
    function setCorner(key, i, act) {
        const put = (group, k, on) => {
            const l = lst(group, k).filter(x => x !== i)
            if (on) l.push(i)
            Sys.writeConf("kwinrc", [group], k, l.length ? l.join(",") : "9")
        }
        put("Effect-overview", "BorderActivate", act === "Overview")
        put("Effect-windowview", "BorderActivateAll", act === "AllWindows")
        put("Effect-windowview", "BorderActivateClass", act === "AppWindows")
        Sys.writeConf("kwinrc", ["ElectricBorders"], key, act === "ShowDesktop" || act === "LockScreen" ? act : "None")
        Sys.detached("dbus-send", ["--session", "--type=method_call", "--dest=org.kde.KWin", "/KWin", "org.kde.KWin.reconfigure"])
        rev++
    }
    // número de esquinas con acción (para el texto del botón)
    function count() {
        let n = 0
        for (const c of [["TopLeft", 7], ["TopRight", 1], ["BottomLeft", 5], ["BottomRight", 3]]) if (action(c[0], c[1]) !== 0) n++
        return n
    }

    background: Rectangle { radius: 14; color: Theme.windowBg; border.width: 0.5; border.color: Theme.sidebarEdge }

    component Corner: MacPopup {
        property string key
        property int idx
        model: hc.labels
        currentIndex: hc.action(key, idx)
        onActivated: (n) => hc.setCorner(key, idx, hc.acts[n])
    }

    contentItem: ColumnLayout {
        spacing: 16
        Txt { text: "Esquinas activas"; font.weight: Font.DemiBold; font.pixelSize: 15 }
        Txt {
            Layout.preferredWidth: 520
            text: "Lleva el puntero a una esquina de la pantalla para hacer una acción."
            color: Theme.secondary; font.pixelSize: Theme.smallSize; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        GridLayout {
            columns: 3
            columnSpacing: 14; rowSpacing: 10
            Corner { key: "TopLeft"; idx: 7; Layout.alignment: Qt.AlignRight | Qt.AlignTop }
            // la pantalla, con el fondo actual, entre los cuatro desplegables
            Rectangle {
                Layout.rowSpan: 2
                Layout.preferredWidth: 200; Layout.preferredHeight: 126
                radius: 8; color: "#0b0b0d"
                border.width: 1; border.color: Theme.cardEdge
                Image {
                    anchors.fill: parent; anchors.margins: 4
                    source: {
                        const m = Sys.readText(Sys.home() + "/.config/plasma-org.kde.plasma.desktop-appletsrc").match(/^Image=(.+)$/m)
                        return m && /\.(jpe?g|png|webp)$/i.test(m[1].trim()) ? m[1].trim() : ""
                    }
                    fillMode: Image.PreserveAspectCrop; sourceSize.width: 400; asynchronous: true
                }
            }
            Corner { key: "TopRight"; idx: 1; Layout.alignment: Qt.AlignLeft | Qt.AlignTop }
            Corner { key: "BottomLeft"; idx: 5; Layout.alignment: Qt.AlignRight | Qt.AlignBottom }
            Corner { key: "BottomRight"; idx: 3; Layout.alignment: Qt.AlignLeft | Qt.AlignBottom }
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            MacButton { text: "OK"; primary: true; onClicked: hc.close() }
        }
    }
}
