import QtQuick

Item {
    id: cb
    property bool checked: false
    property bool on: checked
    onCheckedChanged: on = checked
    signal toggled(bool value)
    implicitWidth: 18
    implicitHeight: 18
    Rectangle {
        anchors.fill: parent
        radius: 5
        color: cb.on ? Theme.accent : Theme.checkOff
        border.width: cb.on ? 0 : 0.5
        border.color: Theme.separator
    }
    Canvas {
        anchors.fill: parent
        visible: cb.on
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = "white"; c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round"
            c.beginPath(); c.moveTo(width * 0.27, height * 0.52); c.lineTo(width * 0.44, height * 0.69); c.lineTo(width * 0.74, height * 0.33); c.stroke()
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { cb.on = !cb.on; cb.toggled(cb.on) }
    }
}
