import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

// Nombre de la app activa, en negrita, a la derecha del logo (como "Finder" en macOS).
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.TasksModel {
        id: tasks
        filterByScreen: false
        filterByVirtualDesktop: false
        filterByActivity: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    readonly property string appName: {
        const i = tasks.activeTask
        if (!i || !i.valid) return "Escritorio"
        const n = tasks.data(i, TaskManager.AbstractTasksModel.AppName) || tasks.data(i, Qt.DisplayRole) || ""
        return n || "Escritorio"
    }

    fullRepresentation: Item {
        Layout.preferredWidth: label.implicitWidth + 12
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Text {
            id: label
            anchors.centerIn: parent
            text: root.appName
            color: Kirigami.Theme.textColor
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize > 0 ? Kirigami.Theme.defaultFont.pixelSize : 13
            font.pointSize: Kirigami.Theme.defaultFont.pixelSize > 0 ? -1 : Kirigami.Theme.defaultFont.pointSize
            font.weight: Font.Bold
            renderType: Text.NativeRendering
        }
    }
}
