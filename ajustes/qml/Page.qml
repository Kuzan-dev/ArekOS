import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

// Página desplazable; los hijos se apilan como tarjetas.
QQC.ScrollView {
    id: page
    property string title: ""
    property string pageId: ""
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
        spacing: 10
        Item { Layout.preferredHeight: 2 }
    }
    // los módulos QML de KDE se abren dentro de la ventana; los antiguos (QWidget), en la suya
    function kcm(name) { if (Sys.kcmEmbeddable(name)) page.open("kde:" + name); else Sys.detached("kcmshell6", [name]) }
    function kwinReconfigure() { Sys.detached("dbus-send", ["--session", "--type=method_call", "--dest=org.kde.KWin", "/KWin", "org.kde.KWin.reconfigure"]) }
    function plasmaScript(js) { Sys.runAsync("plasma", "dbus-send", ["--session", "--print-reply", "--type=method_call", "--dest=org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", "string:" + js]) }
    function idx(list, value, def) { const i = list.indexOf(value); return i < 0 ? (def === undefined ? 0 : def) : i }
}
