import QtQuick
import QtQuick.Layouts

// Fila de ajustes: [casilla] [icono] Título / subtítulo ....... [control] [>]
Item {
    id: row
    property string title: ""
    property string subtitle: ""
    property string tileIcon: ""
    property string tileGlyph: ""
    property color tileColor: Theme.tile.blue
    property bool chevron: false
    property bool hasCheck: false
    property alias checked: chk.checked
    property bool separatorVisible: true
    property bool dimmed: false
    property real minHeight: (tileIcon !== "" || tileGlyph !== "" || hasCheck) ? 34 : 30
    default property alias trailing: trail.data
    signal clicked()
    signal checkToggled(bool value)

    Layout.fillWidth: true
    implicitHeight: Math.max(minHeight, texts.implicitHeight + 12)

    Rectangle {
        visible: row.separatorVisible
        x: 14; width: parent.width - 28; height: 1
        color: Theme.separator
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 9
        color: Theme.control
        visible: row.chevron && ma.pressed
    }
    MouseArea { id: ma; anchors.fill: parent; enabled: row.chevron; onClicked: row.clicked(); cursorShape: row.chevron ? Qt.PointingHandCursor : Qt.ArrowCursor }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 9
        MacCheck { id: chk; visible: row.hasCheck; onToggled: (v) => row.checkToggled(v) }
        Tile { visible: row.tileIcon !== "" || row.tileGlyph !== ""; icon: row.tileIcon; glyph: row.tileGlyph; base: row.tileColor; size: 20 }
        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: row.title; color: row.dimmed ? Theme.tertiary : Theme.text }
            Txt { Layout.fillWidth: true; visible: row.subtitle !== ""; text: row.subtitle; color: Theme.secondary; font.pixelSize: Theme.smallSize; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        }
        Row { id: trail; spacing: 8; Layout.alignment: Qt.AlignVCenter }
        Chevron { visible: row.chevron; Layout.alignment: Qt.AlignVCenter }
    }
}
