import QtQuick
import QtQuick.Controls as QQC

QQC.Popup {
    id: m
    property var items: []
    property int current: -1
    signal picked(int index)
    function popup(target, x, y) {
        const p = target.mapToItem(QQC.Overlay.overlay, x, y)
        m.x = Math.max(8, p.x); m.y = p.y; m.open()
    }
    parent: QQC.Overlay.overlay
    padding: 5
    width: Math.max(160, col.implicitWidth + 10)
    background: Rectangle {
        radius: 10
        color: Theme.menuBg
        border.width: 0.5
        border.color: Theme.dark ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.15)
    }
    contentItem: Column {
        id: col
        Repeater {
            model: m.items
            Rectangle {
                width: Math.max(150, lbl.implicitWidth + 40)
                height: 24
                radius: 5
                color: hov.containsMouse ? Theme.accent : "transparent"
                Txt {
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    text: index === m.current ? "✓" : ""
                    color: hov.containsMouse ? "white" : Theme.text
                }
                Txt {
                    id: lbl
                    x: 26; anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: hov.containsMouse ? "white" : Theme.text
                }
                MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true; onClicked: { m.close(); m.picked(index) } }
            }
        }
    }
}
