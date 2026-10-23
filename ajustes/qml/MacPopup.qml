import QtQuick
import QtQuick.Controls as QQC

// Botón desplegable de macOS: valor + chevrons ⌃⌄ en una cápsula.
Item {
    id: pop
    property var model: []          // textos visibles
    property int currentIndex: 0
    // lo que se muestra: la elección inmediata, pero vuelve a seguir a currentIndex cuando el valor real cambia
    // (asignar currentIndex rompía el enlace y el desplegable dejaba de reflejar el estado del sistema)
    property int shownIndex: currentIndex
    onCurrentIndexChanged: shownIndex = currentIndex
    property bool enabled2: true
    signal activated(int index)
    implicitWidth: row.implicitWidth + 6
    implicitHeight: 22
    opacity: enabled2 ? 1 : 0.45

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        spacing: 8
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: pop.model.length ? pop.model[Math.max(0, pop.shownIndex)] || "" : ""
            color: Theme.text
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 9
            color: ma.pressed ? Theme.controlPressed : Theme.control
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const c = getContext("2d"); c.reset()
                    c.strokeStyle = Theme.dark ? "#DDDDDD" : "#3A3A3C"; c.lineWidth = 1.4; c.lineCap = "round"; c.lineJoin = "round"
                    c.beginPath(); c.moveTo(6, 7.5); c.lineTo(9, 4.8); c.lineTo(12, 7.5); c.stroke()
                    c.beginPath(); c.moveTo(6, 10.5); c.lineTo(9, 13.2); c.lineTo(12, 10.5); c.stroke()
                }
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: pop.enabled2
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.popup(pop, pop.width - menu.width, -4)
    }
    MacMenu {
        id: menu
        items: pop.model
        current: pop.shownIndex
        onPicked: (i) => { pop.shownIndex = i; pop.activated(i) }
    }
}
