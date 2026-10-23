import QtQuick
import QtQuick.Layouts

// Grupo de filas con fondo gris y separadores interiores (como en macOS).
Rectangle {
    id: card
    default property alias rows: col.data
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight
    radius: 10
    color: Theme.card
    border.width: 1
    border.color: Theme.cardEdge
    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0
    }
    function relayout() {
        let first = true
        for (let i = 0; i < col.children.length; ++i) {
            const c = col.children[i]
            if (c.separatorVisible === undefined || !c.visible) continue
            c.separatorVisible = !first
            first = false
        }
    }
    Component.onCompleted: relayout()
    Connections { target: col; function onChildrenChanged() { Qt.callLater(card.relayout) } }
}
