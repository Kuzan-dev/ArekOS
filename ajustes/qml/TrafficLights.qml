import QtQuick
import QtQuick.Window

// Semáforos de macOS (Monterey/Sequoia a 1x), idénticos a los de la decoración de ventanas de Vitrum:
// 12 px con borde de 1 px más oscuro, 20 px entre centros; ×, − y pantalla completa en los tres a la vez
// al pasar el ratón; grises en ventanas inactivas.
Item {
    id: tl
    width: 52
    height: 12
    property bool hovered: hov.containsMouse
    // external: no actúa sobre su ventana, solo avisa (p. ej. en las miniaturas de la vista previa del Dock)
    property bool external: false
    property bool alwaysColored: false
    signal closeClicked()
    signal minimizeClicked()
    signal zoomClicked()
    readonly property var win: Window.window
    readonly property var fills: ["#FF5F57", "#FEBC2E", "#28C840"]
    readonly property var rims: ["#E0443E", "#DEA123", "#1AAB29"]
    readonly property var glyphs: ["#4D0000", "#995700", "#006500"]
    readonly property bool colored: alwaysColored || (win && win.active) || hovered
    MouseArea { id: hov; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    Repeater {
        model: 3
        Canvas {
            id: c
            required property int index
            x: index * 20
            width: 12; height: 12
            property bool pressed: ma.pressed
            readonly property color fill: tl.colored ? tl.fills[index] : (Theme.dark ? "#4E4E50" : "#CFCFCF")
            readonly property color rim: tl.colored ? tl.rims[index] : (Theme.dark ? "#3C3C3E" : "#B4B4B4")
            onFillChanged: requestPaint()
            onPressedChanged: requestPaint()
            Connections { target: tl; function onHoveredChanged() { c.requestPaint() } }
            onPaint: {
                const g = getContext("2d")
                g.reset()
                const dk = (col) => pressed ? Qt.darker(col, 1.18) : col
                g.fillStyle = dk(rim); g.beginPath(); g.arc(6, 6, 6, 0, 2 * Math.PI); g.fill()
                g.fillStyle = dk(fill); g.beginPath(); g.arc(6, 6, 5, 0, 2 * Math.PI); g.fill()
                if (!tl.hovered) return
                g.globalAlpha = 0.85
                g.strokeStyle = tl.glyphs[index]; g.fillStyle = tl.glyphs[index]
                g.lineWidth = 1.2; g.lineCap = "round"
                if (index === 0) {
                    g.beginPath(); g.moveTo(3.7, 3.7); g.lineTo(8.3, 8.3); g.moveTo(8.3, 3.7); g.lineTo(3.7, 8.3); g.stroke()
                } else if (index === 1) {
                    g.fillRect(2.6, 5.4, 6.8, 1.2)
                } else {
                    g.beginPath(); g.moveTo(3.2, 3.2); g.lineTo(7.8, 3.2); g.lineTo(3.2, 7.8); g.closePath(); g.fill()
                    g.beginPath(); g.moveTo(8.8, 8.8); g.lineTo(4.2, 8.8); g.lineTo(8.8, 4.2); g.closePath(); g.fill()
                }
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                onClicked: {
                    if (tl.external) {
                        if (index === 0) tl.closeClicked(); else if (index === 1) tl.minimizeClicked(); else tl.zoomClicked()
                        return
                    }
                    if (index === 0) tl.win.close()
                    else if (index === 1) tl.win.showMinimized()
                    else tl.win.visibility === Window.Maximized ? tl.win.showNormal() : tl.win.showMaximized()
                }
            }
        }
    }
}
