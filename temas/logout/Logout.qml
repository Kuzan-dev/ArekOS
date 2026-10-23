import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions
import org.kde.plasma.plasma5support as P5Support

// Diálogo de apagar / reiniciar / cerrar sesión al estilo de macOS (Monterey/Sequoia).
// Contexto que proporciona el sistema: sdtype, ShutdownType, maysd, spdMethods, screenGeometry, softwareUpdatePending.
Item {
    id: root
    width: screenGeometry.width
    height: screenGeometry.height

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()
    function sleepRequested() { root.suspendRequested(2) }
    function hibernateRequested() { root.suspendRequested(4) }

    readonly property bool dark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    readonly property bool all: sdtype === ShutdownType.ShutdownTypeDefault
    property int remaining: 60
    readonly property string what: sdtype === ShutdownType.ShutdownTypeReboot ? "reiniciar"
                                  : sdtype === ShutdownType.ShutdownTypeHalt ? "apagar" : "cerrar"
    function act() {
        if (sdtype === ShutdownType.ShutdownTypeReboot) softwareUpdatePending ? rebootUpdateRequested() : rebootRequested()
        else if (sdtype === ShutdownType.ShutdownTypeHalt) softwareUpdatePending ? haltUpdateRequested() : haltRequested()
        else logoutRequested()
    }

    // "Volver a abrir las ventanas al iniciar sesión" = restaurar la sesión anterior
    P5Support.DataSource {
        id: sh
        engine: "executable"
        property bool restore: true
        onNewData: (src, data) => {
            if (src.indexOf("kreadconfig6") >= 0) restore = (data.stdout || "").trim() !== "emptySession"
            disconnectSource(src)
        }
        Component.onCompleted: connectSource("kreadconfig6 --file ksmserverrc --group General --key loginMode")
        function setRestore(v) {
            restore = v
            connectSource("kwriteconfig6 --file ksmserverrc --group General --key loginMode " + (v ? "restorePreviousLogout" : "emptySession") + " #" + Date.now())
        }
    }

    Timer {
        interval: 1000; repeat: true; running: !root.all
        onTriggered: { root.remaining--; if (root.remaining <= 0) { running = false; root.act() } }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.25) }
    MouseArea { anchors.fill: parent; onClicked: root.cancelRequested() }
    Keys.onEscapePressed: root.cancelRequested()
    focus: true

    Rectangle {
        id: dlg
        anchors.centerIn: parent
        width: 290
        height: col.implicitHeight + 32
        radius: 12
        color: root.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.96) : Qt.rgba(0.95, 0.95, 0.96, 0.97)
        border.width: 0.5
        border.color: root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.18)
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 10

            Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; source: "computer"; implicitWidth: 64; implicitHeight: 64 }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: root.dark ? "white" : "#1D1D1F"
                font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Bold
                text: root.all ? "¿Qué quieres hacer?"
                    : root.what === "cerrar" ? "¿Seguro que quieres salir de todas las apps y cerrar la sesión ahora?"
                    : "¿Seguro que quieres " + root.what + " el ordenador ahora?"
            }
            Text {
                visible: !root.all
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: root.dark ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0, 0, 0, 0.7)
                font.family: "Inter"; font.pixelSize: 11
                text: "Si no haces nada, " + (root.what === "cerrar" ? "la sesión se cerrará" : "el ordenador se " + (root.what === "apagar" ? "apagará" : "reiniciará"))
                      + " automáticamente en " + root.remaining + " segundos."
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                Rectangle {
                    width: 14; height: 14; radius: 4
                    color: sh.restore ? Kirigami.Theme.highlightColor : (root.dark ? Qt.rgba(1, 1, 1, 0.12) : "white")
                    border.width: sh.restore ? 0 : 0.5; border.color: Qt.rgba(0, 0, 0, 0.3)
                    Text { anchors.centerIn: parent; visible: sh.restore; text: "✓"; color: "white"; font.pixelSize: 10; font.bold: true }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: sh.setRestore(!sh.restore) }
                }
                Text {
                    color: root.dark ? Qt.rgba(1, 1, 1, 0.85) : "#1D1D1F"
                    font.family: "Inter"; font.pixelSize: 11
                    text: "Volver a abrir las ventanas al iniciar sesión"
                    MouseArea { anchors.fill: parent; onClicked: sh.setRestore(!sh.restore) }
                }
            }

            // Botones: dos en fila (Cancelar · acción) o, si se pidió sin tipo, las cuatro acciones
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                columns: 2
                rowSpacing: 8; columnSpacing: 8
                Repeater {
                    model: root.all
                        ? [{ t: "Reposo", f: () => root.sleepRequested(), v: !!spdMethods.SuspendState },
                           { t: "Reiniciar", f: () => root.rebootRequested(), v: maysd },
                           { t: "Apagar", f: () => root.haltRequested(), v: maysd },
                           { t: "Cerrar sesión", f: () => root.logoutRequested(), v: true },
                           { t: "Cancelar", f: () => root.cancelRequested(), v: true, wide: true }]
                        : [{ t: "Cancelar", f: () => root.cancelRequested(), v: true },
                           { t: root.what === "apagar" ? "Apagar" : root.what === "reiniciar" ? "Reiniciar" : "Cerrar sesión", f: () => root.act(), v: true, def: true }]
                    Rectangle {
                        required property var modelData
                        visible: modelData.v
                        Layout.fillWidth: true
                        Layout.columnSpan: modelData.wide ? 2 : 1
                        height: 28; radius: 7
                        color: modelData.def ? Kirigami.Theme.highlightColor
                             : (ma.pressed ? (root.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)) : (root.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)))
                        Text {
                            anchors.centerIn: parent
                            text: modelData.t
                            color: modelData.def ? "white" : (root.dark ? "white" : "#1D1D1F")
                            font.family: "Inter"; font.pixelSize: 13
                        }
                        MouseArea { id: ma; anchors.fill: parent; onClicked: modelData.f() }
                    }
                }
            }
        }
    }
    Keys.onReturnPressed: root.all ? undefined : root.act()
}
