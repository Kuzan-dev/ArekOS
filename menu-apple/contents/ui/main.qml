import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Menú del logo (equivalente al menú Apple de macOS Monterey) con el logo de Fedora.
// Es un menú nativo: se ve igual que el resto de menús del sistema.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property string bin: "$HOME/.local/bin/"
    readonly property string userName: {
        const n = (sh.fullName || "").trim()
        return n || "usuario"
    }

    P5Support.DataSource {
        id: sh
        engine: "executable"
        property string fullName: ""
        onNewData: (source, data) => {
            if (source.indexOf("getent") >= 0) fullName = ((data.stdout || "").split(":")[4] || "").split(",")[0]
            disconnectSource(source)
        }
        function run(cmd) { connectSource("bash -c '" + cmd.replace(/'/g, "'\\''") + "' #" + Date.now()) }
        Component.onCompleted: connectSource("bash -c 'getent passwd $USER' #nombre")
    }
    function logout(method) {
        sh.run("dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt." + method)
    }

    // activar el widget (atajo de teclado) abre el menú
    onExpandedChanged: if (expanded) { expanded = false; menuOpener.restart() }
    Timer { id: menuOpener; interval: 1; onTriggered: root.openMenu() }
    signal openMenu()

    fullRepresentation: MouseArea {
        id: btn
        Layout.preferredWidth: 34
        Layout.minimumWidth: 34
        Layout.maximumWidth: 34
        onClicked: menu.openRelative()
        Rectangle {
            anchors.centerIn: parent; width: 30; height: 22; radius: 5
            color: menu.status === PlasmaExtras.Menu.Open ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15) : "transparent"
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 16; height: 16
            source: "vitrum-logo-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
        }

        Connections { target: root; function onOpenMenu() { menu.openRelative() } }
        PlasmaExtras.Menu {
            id: menu
            visualParent: btn
            placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
            minimumWidth: 250
            PlasmaExtras.MenuItem { text: "Acerca de este equipo"; onClicked: sh.run(root.bin + "vitrum-ajustes info") }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem { text: "Ajustes del Sistema…"; onClicked: sh.run(root.bin + "vitrum-ajustes") }
            PlasmaExtras.MenuItem { text: "App Store…"; onClicked: sh.run("plasma-discover") }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem { text: "Ítems recientes"; onClicked: sh.run("dolphin recentlyused:/files") }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem { text: "Forzar salida…\tCtrl+Esc"; onClicked: sh.run("plasma-systemmonitor --page-name Applications") }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem { text: "Reposo"; onClicked: sh.run("systemctl suspend") }
            PlasmaExtras.MenuItem { text: "Reiniciar…"; onClicked: root.logout("promptReboot") }
            PlasmaExtras.MenuItem { text: "Apagar equipo…"; onClicked: root.logout("promptShutDown") }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem { text: "Bloquear pantalla\tSuper+L"; onClicked: sh.run("loginctl lock-session") }
            PlasmaExtras.MenuItem { text: "Cerrar sesión de " + root.userName + "…"; onClicked: root.logout("promptLogout") }
        }
    }
}
