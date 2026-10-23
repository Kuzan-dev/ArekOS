import QtQuick

Item {
    id: sl
    property real from: 0
    property real to: 100
    property real value: 50
    property real stepSize: 0
    signal moved(real value)
    signal released(real value)
    implicitWidth: 200
    implicitHeight: 20
    // posición mostrada: sigue a "value" salvo mientras se arrastra (asignar value rompía el enlace)
    property real shown: value
    onValueChanged: if (!drag.pressed) shown = value
    readonly property real pos: Math.max(0, Math.min(1, (shown - from) / (to - from)))
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 4; radius: 2
        color: Theme.switchOff
        Rectangle { width: parent.width * sl.pos; height: parent.height; radius: 2; color: Theme.accent }
    }
    Rectangle {
        width: 20; height: 20; radius: 10
        x: sl.pos * (sl.width - width)
        anchors.verticalCenter: parent.verticalCenter
        color: "white"
        border.width: 0.5; border.color: Qt.rgba(0, 0, 0, 0.18)
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function upd(mx) {
            let v = sl.from + Math.max(0, Math.min(1, (mx - 10) / (sl.width - 20))) * (sl.to - sl.from)
            if (sl.stepSize > 0) v = Math.round(v / sl.stepSize) * sl.stepSize
            sl.shown = v; sl.moved(v)
        }
        onPressed: (e) => upd(e.x)
        onPositionChanged: (e) => { if (pressed) upd(e.x) }
        onReleased: sl.released(sl.shown)
    }
}
