import QtQuick
import QtQuick.Layouts

// Grupo de botones de opción dentro de una tarjeta (estilo Sequoia).
Item {
    id: rg
    property string title: ""
    property var options: []
    property int current: 0
    property int shown: current
    onCurrentChanged: shown = current
    property bool separatorVisible: true
    signal picked(int index)
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 18
    Rectangle { visible: rg.separatorVisible; x: 14; width: parent.width - 28; height: 1; color: Theme.separator }
    Column {
        id: col
        x: 14; y: 9
        spacing: 5
        Txt { text: rg.title }
        Repeater {
            model: rg.options
            Item {
                width: opt.width; height: opt.height
                Row {
                id: opt
                spacing: 7
                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: index === rg.shown ? Theme.accent : Theme.checkOff
                    border.width: index === rg.shown ? 0 : 0.5; border.color: Theme.separator
                    Rectangle { visible: index === rg.shown; anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: "white" }
                }
                Txt { text: modelData }
                }
                MouseArea { anchors.fill: parent; onClicked: { rg.shown = index; rg.picked(index) } }
            }
        }
    }
}
