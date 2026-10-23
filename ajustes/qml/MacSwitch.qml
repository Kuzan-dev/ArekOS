import QtQuick

// Interruptor de macOS 26 (pequeño, en filas de ajustes).
Item {
    id: sw
    property bool checked: false
    // asignar "checked" desde dentro rompía el enlace con la configuración; se muestra "on"
    property bool on: checked
    onCheckedChanged: on = checked
    property bool enabled2: true
    signal toggled(bool value)
    implicitWidth: 34
    implicitHeight: 19
    opacity: enabled2 ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.on ? Theme.accent : Theme.switchOff
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Rectangle {
        id: knob
        width: parent.height - 3
        height: width
        radius: width / 2
        y: 1.5
        x: sw.on ? parent.width - width - 1.5 : 1.5
        color: "white"
        border.width: 0.5
        border.color: Qt.rgba(0, 0, 0, 0.10)
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: sw.enabled2
        cursorShape: Qt.PointingHandCursor
        onClicked: { sw.on = !sw.on; sw.toggled(sw.on) }
    }
}
