import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

// Hoja modal estilo macOS (p. ej. pedir la contraseña de una red).
QQC.Popup {
    id: sh
    property string heading: ""
    property string message: ""
    property string placeholder: ""
    property bool password: true
    property alias value: field.text
    signal accepted(string value)
    parent: QQC.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    width: 360
    padding: 18
    background: Rectangle { radius: 14; color: Theme.windowBg; border.width: 0.5; border.color: Theme.sidebarEdge }
    QQC.Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.18) }
    onOpened: { field.text = ""; field.forceActiveFocus() }
    contentItem: ColumnLayout {
        spacing: 10
        Txt { Layout.fillWidth: true; text: sh.heading; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        Txt { Layout.fillWidth: true; visible: sh.message !== ""; text: sh.message; color: Theme.secondary; font.pixelSize: Theme.smallSize; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        Rectangle {
            Layout.fillWidth: true; height: 26; radius: 6
            color: Theme.card; border.width: 1; border.color: field.activeFocus ? Theme.accent : Theme.separator
            TextInput {
                id: field
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                echoMode: sh.password ? TextInput.Password : TextInput.Normal
                font.family: Theme.font; font.pixelSize: Theme.fontSize; color: Theme.text
                onAccepted: { sh.close(); sh.accepted(text) }
                Txt { visible: !field.text; text: sh.placeholder; color: Theme.tertiary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8
            MacButton { text: "Cancelar"; onClicked: sh.close() }
            MacButton { text: "Aceptar"; primary: true; onClicked: { sh.close(); sh.accepted(field.text) } }
        }
    }
}
