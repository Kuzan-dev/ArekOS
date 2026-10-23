import QtQuick
import QtQuick.Layouts

// Sección "Opciones de KDE": acceso a los módulos nativos completos (se abren dentro de la ventana si son
// QML; los antiguos, en la suya). Así cada página tiene lo de macOS arriba y todo lo de KDE aquí.
ColumnLayout {
    id: ko
    property var page                 // la página (para abrir el módulo)
    property var items: []            // [{ t: título, k: módulo, s: subtítulo, icon }]
    property string heading: "Opciones de KDE"
    Layout.fillWidth: true
    spacing: 10
    SectionHeader { text: ko.heading }
    Card {
        Repeater {
            model: ko.items
            RowItem {
                title: modelData.t
                subtitle: modelData.s || ""
                tileIcon: modelData.icon || "preferences-system-symbolic"
                tileColor: Theme.tile.graphite
                chevron: true
                onClicked: modelData.run ? Sys.detached(modelData.run, modelData.args || []) : ko.page.kcm(modelData.k)
            }
        }
    }
}
