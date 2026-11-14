import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Icono del Centro de Control en la barra de menús. El panel lo dibuja vitrum-shell (ControlCenter.qml):
// así flota separado de la barra y del borde, con las cuatro esquinas y el material medidos en macOS,
// cosa que un menú emergente de Plasma (pegado a la barra) no permite.
PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // abierto: el icono se resalta con una píldora, como en macOS Tahoe. Se marca al pulsar y, mientras siga
    // abierto, se pregunta a vitrum-shell (org.vitrum.Shell.Abierto) hasta que se cierre
    property bool abierto: false
    property real pulsado: 0
    Timer {
        id: vigila
        interval: 300; repeat: true
        onTriggered: sh.connectSource("dbus-send --session --print-reply=literal --dest=org.vitrum.Shell /Shell org.vitrum.Shell.Abierto #" + Date.now())
    }
    P5Support.DataSource {
        id: sh; engine: "executable"
        onNewData: (s, data) => {
            // la respuesta puede llegar antes de que vitrum-shell procese el clic: se ignora el primer instante
            if (s.indexOf("org.vitrum.Shell.Abierto") >= 0 && Date.now() - root.pulsado > 500) {
                root.abierto = (data.stdout || "").trim() === "cc"
                if (!root.abierto) vigila.stop()
            }
            disconnectSource(s)
        }
    }
    function toggle() {
        pressedLook.restart()
        abierto = !abierto
        pulsado = Date.now()
        vigila.restart()
        sh.connectSource("dbus-send --session --print-reply --type=method_call --dest=org.vitrum.Shell /Shell org.vitrum.Shell.ToggleControlCenter #" + Date.now())
    }
    // Super+A (atajo del widget)
    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    Timer { id: pressedLook; interval: 180 }

    // Icono de la barra de menús: dos interruptores
    compactRepresentation: MouseArea {
        // mismo paso que los iconos de la bandeja (30 px entre centros) y 19 px hasta el reloj, como en macOS
        Layout.preferredWidth: 32
        Layout.minimumWidth: 32
        Layout.maximumWidth: 32
        onClicked: root.toggle()
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: 26; height: 20; radius: 10
            color: parent.pressed || pressedLook.running ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.28) : root.abierto ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2) : "transparent"
            Column {
                anchors.centerIn: parent; spacing: 2.5
                Repeater {
                    model: 2
                    Rectangle {
                        width: 15; height: 6.5; radius: 3.25
                        color: "transparent"; border.width: 1.3; border.color: Kirigami.Theme.textColor
                        Rectangle {
                            width: 3.6; height: 3.6; radius: 1.8
                            anchors.verticalCenter: parent.verticalCenter
                            x: index === 0 ? parent.width - width - 1.4 : 1.4
                            color: Kirigami.Theme.textColor
                        }
                    }
                }
            }
        }
    }
    fullRepresentation: Item {}
}
