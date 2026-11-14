import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

// Página desplazable; los hijos se apilan como tarjetas.
QQC.ScrollView {
    id: page
    property string title: ""
    property string pageId: ""
    // cabecera de Tahoe: icono grande, título y descripción (Main la rellena en las secciones de la barra lateral)
    property string heroIcon: ""
    property string heroGlyph: ""
    property color heroColor: Theme.tile.blue
    property string heroDesc: ""
    default property alias content: col.data
    property alias column: col
    signal open(string id)
    clip: true
    contentWidth: availableWidth
    contentHeight: col.implicitHeight + 24
    QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff
    ColumnLayout {
        id: col
        width: page.availableWidth - 32
        x: 16
        spacing: 12
        Item { Layout.preferredHeight: 2 }
        Rectangle {
            visible: page.heroDesc !== ""
            Layout.fillWidth: true
            implicitHeight: heroCol.implicitHeight + 40
            radius: 14
            color: Theme.card
            border.width: 1; border.color: Theme.cardEdge
            Column {
                id: heroCol
                y: 22
                width: parent.width - 48; x: 24
                spacing: 6
                Tile {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 60
                    icon: page.heroIcon; glyph: page.heroGlyph; base: page.heroColor
                }
                Item { width: 1; height: 2 }
                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: page.title
                    font.pixelSize: 24; font.weight: Font.Bold
                }
                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: page.heroDesc
                    color: Theme.secondary
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                }
            }
        }
    }
    // los módulos QML de KDE se abren dentro de la ventana; los antiguos (QWidget), en la suya
    function kcm(name) { if (Sys.kcmEmbeddable(name)) page.open("kde:" + name); else Sys.detached("kcmshell6", [name]) }
    function kwinReconfigure() { Sys.detached("dbus-send", ["--session", "--type=method_call", "--dest=org.kde.KWin", "/KWin", "org.kde.KWin.reconfigure"]) }
    function plasmaScript(js) { Sys.runAsync("plasma", "dbus-send", ["--session", "--print-reply", "--type=method_call", "--dest=org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", "string:" + js]) }
    function idx(list, value, def) { const i = list.indexOf(value); return i < 0 ? (def === undefined ? 0 : def) : i }
}
