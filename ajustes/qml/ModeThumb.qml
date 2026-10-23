import QtQuick

// Miniatura de "Aspecto" (Claro / Oscuro / Automático) como en macOS.
Column {
    id: mt
    property string mode: "claro"
    property string label: ""
    property bool selected: false
    signal clicked()
    spacing: 5
    Rectangle {
        width: 68; height: 46; radius: 8
        color: "transparent"
        border.width: mt.selected ? 3 : 0
        border.color: Theme.accent
        Item {
            anchors.fill: parent; anchors.margins: mt.selected ? 3 : 0
            clip: true
            Rectangle {
                anchors.fill: parent; radius: 6
                gradient: Gradient {
                    GradientStop { position: 0; color: "#4FA3F7" }
                    GradientStop { position: 1; color: "#1E4FD8" }
                }
            }
            Repeater {
                model: mt.mode === "auto" ? 2 : 1
                Item {
                    readonly property bool darkHalf: mt.mode === "oscuro" || (mt.mode === "auto" && index === 1)
                    x: mt.mode === "auto" ? index * parent.width / 2 : 0
                    width: mt.mode === "auto" ? parent.width / 2 : parent.width
                    height: parent.height
                    clip: true
                    Rectangle {
                        x: 8 - parent.x; y: 9; width: 52; height: 31; radius: 4
                        color: darkHalf ? "#2B2B2E" : "#F4F4F6"
                        Rectangle { x: 0; y: 0; width: 14; height: parent.height; radius: 4; color: darkHalf ? "#3A3A3E" : "#DCE6F3" }
                        Row {
                            x: 3; y: 3; spacing: 2
                            Repeater { model: ["#FF5F57", "#FEBC2E", "#28C840"]; Rectangle { width: 3; height: 3; radius: 1.5; color: modelData } }
                        }
                        Rectangle { x: 18; y: 6; width: 26; height: 3; radius: 1.5; color: Theme.accent }
                        Rectangle { x: 18; y: 12; width: 30; height: 3; radius: 1.5; color: darkHalf ? "#55555A" : "#D0D0D5" }
                        Rectangle { x: 18; y: 18; width: 22; height: 3; radius: 1.5; color: darkHalf ? "#55555A" : "#D0D0D5" }
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mt.clicked() }
    }
    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        text: mt.label
        font.pixelSize: Theme.smallSize
        font.weight: mt.selected ? Font.DemiBold : Font.Normal
        color: mt.selected ? Theme.text : Theme.secondary
    }
}
