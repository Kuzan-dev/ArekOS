import QtQuick

// Flechas atrás/adelante sueltas, como en la barra de herramientas de Sequoia.
Row {
    id: na
    property bool canBack: false
    property bool canForward: false
    signal backClicked()
    signal forwardClicked()
    spacing: 4
    Repeater {
        model: 2
        Rectangle {
            width: 26; height: 24; radius: 6
            color: ma.pressed ? Theme.controlPressed : (ma.containsMouse && (index === 0 ? na.canBack : na.canForward) ? Theme.control : "transparent")
            Chevron {
                anchors.centerIn: parent
                pointLeft: index === 0
                tint: (index === 0 ? na.canBack : na.canForward) ? Theme.secondary : Theme.tertiary
            }
            MouseArea {
                id: ma
                anchors.fill: parent; hoverEnabled: true
                onClicked: index === 0 ? na.backClicked() : na.forwardClicked()
            }
        }
    }
}
