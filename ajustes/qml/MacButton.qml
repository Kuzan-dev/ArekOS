import QtQuick

Rectangle {
    id: b
    property string text: ""
    property bool primary: false
    signal clicked()
    implicitWidth: label.implicitWidth + 24
    implicitHeight: 24
    radius: 7
    color: primary ? Theme.accent : (ma.pressed ? Theme.controlPressed : Theme.control)
    Txt {
        id: label
        anchors.centerIn: parent
        text: b.text
        color: b.primary ? "white" : Theme.text
    }
    MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
