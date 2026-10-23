import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Lupa de la barra de menús: abre Spotlight (KRunner).
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // Ajustes → Spotlight puede ocultar la lupa (vitrumrc [Spotlight] MenuBarIcon)
    property bool shown: true
    P5Support.DataSource {
        id: sh; engine: "executable"
        onNewData: (src, data) => {
            if (src.indexOf("kreadconfig6") >= 0) root.shown = (data["stdout"] || "").trim() !== "false"
            disconnectSource(src)
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: sh.connectSource("kreadconfig6 --file vitrumrc --group Spotlight --key MenuBarIcon #" + Date.now()) }
    fullRepresentation: MouseArea {
        visible: root.shown
        Layout.preferredWidth: root.shown ? 23 : 0
        Layout.minimumWidth: root.shown ? 23 : 0
        Layout.maximumWidth: root.shown ? 23 : 0
        onClicked: sh.connectSource("dbus-send --session --print-reply --type=method_call --dest=org.vitrum.Shell /Shell org.vitrum.Shell.ToggleSpotlight #" + Date.now())
        id: lupa
        // resaltado al pulsar, como los iconos de la barra de menús de macOS
        // la lupa va centrada en x=10 (no en el centro): así queda a 30 px de la bandeja y del Centro de Control
        Rectangle { anchors.verticalCenter: parent.verticalCenter; x: -3; width: 26; height: 20; radius: 5; color: Qt.rgba(1, 1, 1, 0.25); visible: lupa.pressed }
        // Lupa dibujada (no depende del tema de iconos)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            x: 2.5
            width: 15; height: 15
            Rectangle { x: 0; y: 0; width: 11; height: 11; radius: 5.5; color: "transparent"; border.width: 1.6; border.color: Kirigami.Theme.textColor }
            Rectangle { x: 9.2; y: 11.2; width: 6; height: 1.8; radius: 0.9; rotation: 45; transformOrigin: Item.Left; color: Kirigami.Theme.textColor }
        }
    }
}
