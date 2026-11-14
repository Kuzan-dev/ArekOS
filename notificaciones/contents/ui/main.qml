import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.kquickcontrolsaddons as KQuickAddons

// Centro de Notificaciones de la barra de menús, como en macOS Tahoe: la campana abre las notificaciones en
// tarjetas de cristal, con la letra de los menús de Wi‑Fi y Sonido. Va dentro de plasmashell porque el historial
// vive ahí; la campana de KDE sigue cargada en un panel escondido (vitrum-disposicion, paso 4) porque es la que
// muestra las notificaciones emergentes.
PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property string bin: "$HOME/.local/bin/"

    property date now: new Date()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = new Date() }

    // ── Colores (sobre el fondo de los menús emergentes de Plasma) ───────────
    readonly property color fg: Kirigami.Theme.textColor
    readonly property bool dark: (fg.r + fg.g + fg.b) / 3 > 0.5
    readonly property color fg2: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property color glass: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.5)
    readonly property color glassHover: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.65)
    readonly property color glassEdge: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.8)
    readonly property color sep: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)

    // ── Notificaciones: el mismo historial que muestra la campana de KDE ─────
    NotificationManager.Settings { id: ajustesNotif; live: true }
    readonly property bool noMolestar: ajustesNotif.notificationsInhibitedUntil > now
    NotificationManager.Notifications {
        id: historial
        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        limit: 50
        lastRead: Plasmoid.configuration.lastRead
    }
    onExpandedChanged: if (expanded) { now = new Date(); Plasmoid.configuration.lastRead = now }
    function borrarTodo() {
        historial.clear(NotificationManager.Notifications.ClearExpired)
        for (let i = historial.count - 1; i >= 0; i--) historial.close(historial.index(i, 0))
    }
    function cuando(d) {
        if (!d) return ""
        const min = Math.floor((now - d) / 60000)
        if (min < 1) return "ahora"
        if (min < 60) return "hace " + min + " min"
        const hoy = new Date(now); hoy.setHours(0, 0, 0, 0)
        if (d >= hoy) return Qt.formatTime(d, "HH:mm")
        if (d >= new Date(hoy.getTime() - 86400000)) return "ayer"
        return Qt.locale().toString(d, "d MMM")
    }

    P5Support.DataSource { id: sh; engine: "executable"; onNewData: (s) => disconnectSource(s) }
    function run(cmd) { sh.connectSource(cmd + " #" + Date.now()) }
    // las apps se abren en su propio grupo de procesos (scope de systemd): si cuelgan de plasmashell, Plasma las
    // cierra al reiniciarse (y con ellas lo que estuvieran haciendo, como aplicar una opción de la barra)
    function abrir(cmd) { run("setsid -f systemd-run --user --scope --collect --quiet " + cmd) }

    // clic derecho
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Ajustes de notificaciones…"
            icon.name: "preferences-desktop-notification"
            onTriggered: root.abrir(root.bin + "vitrum-ajustes notificaciones")
        }
    ]

    // ── En la barra: la campana, con la píldora de Tahoe mientras está abierto ──
    compactRepresentation: MouseArea {
        id: compacto
        Layout.preferredWidth: 30
        Layout.minimumWidth: 30
        Layout.maximumWidth: 30
        onClicked: root.expanded = !root.expanded
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: 26; height: 20; radius: 10
            color: compacto.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.28)
                 : root.expanded ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2) : "transparent"
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16; height: 16
                source: root.noMolestar ? "notification-disabled-symbolic"
                      : historial.unreadNotificationsCount > 0 ? "notification-active-symbolic" : "notification-inactive-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
    }

    // ── Centro de Notificaciones ─────────────────────────────────────────────
    // medidas de letra de los menús de Wi‑Fi y Sonido: título 13 px en negrita, texto 13 px, datos 11 px
    fullRepresentation: Item {
        Layout.preferredWidth: 340
        Layout.minimumWidth: 340
        Layout.maximumWidth: 340
        Layout.preferredHeight: Math.min(contenido.implicitHeight + 20, 640)
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight

        Flickable {
            anchors.fill: parent
            anchors.margins: 10
            contentHeight: contenido.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: contenido
                width: parent.width
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.preferredHeight: 26
                    T { text: "Notificaciones"; font.weight: Font.Bold; Layout.fillWidth: true }
                    Rectangle {
                        visible: historial.count > 0
                        implicitWidth: borrar.implicitWidth + 20; implicitHeight: 22; radius: 11
                        color: borrarMa.containsMouse ? root.glassHover : root.glass
                        border.width: 1; border.color: root.glassEdge
                        T { id: borrar; anchors.centerIn: parent; text: "Borrar todo"; font.pixelSize: 11; font.weight: Font.DemiBold }
                        MouseArea { id: borrarMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.borrarTodo() }
                    }
                }

                // sin notificaciones
                Rectangle {
                    visible: historial.count === 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    implicitHeight: 56
                    radius: 18
                    color: root.glass
                    border.width: 1; border.color: root.glassEdge
                    T { anchors.centerIn: parent; text: root.noMolestar ? "No molestar activado" : "Sin notificaciones"; color: root.fg2 }
                }

                Repeater {
                    model: historial
                    delegate: Tarjeta {}
                }

                // como «Ajustes de Wi‑Fi…» al pie de los menús
                Rectangle { Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 4; implicitHeight: 1; color: root.sep }
                T {
                    Layout.leftMargin: 10
                    text: "Ajustes de notificaciones…"
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { root.abrir(root.bin + "vitrum-ajustes notificaciones"); root.expanded = false } }
                }
            }
        }
    }

    // ── Piezas ───────────────────────────────────────────────────────────────
    component T: Text {
        color: root.fg
        font.pixelSize: 13
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }

    // tarjeta de notificación: icono de la app, nombre y hora, título y texto; la ✕ aparece al pasar el ratón
    component Tarjeta: Rectangle {
        id: tj
        required property var model
        required property int index
        Layout.fillWidth: true
        // hueco para la ✕, que sobresale 5 px por arriba y por la izquierda (si no, la recorta el Flickable)
        Layout.leftMargin: 6
        Layout.topMargin: 2
        implicitHeight: cuerpo.implicitHeight + 22
        radius: 18
        color: tjHover.hovered ? root.glassHover : root.glass
        border.width: 1; border.color: root.glassEdge
        HoverHandler { id: tjHover }
        MouseArea {
            anchors.fill: parent
            enabled: !!tj.model.hasDefaultAction
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: { historial.invokeDefaultAction(historial.index(tj.index, 0), NotificationManager.Notifications.Close); root.expanded = false }
        }
        Item {
            x: 11; y: 11
            width: 30; height: 30
            Loader {
                anchors.fill: parent
                active: !!tj.model.image
                sourceComponent: KQuickAddons.QImageItem {
                    image: tj.model.image
                    fillMode: KQuickAddons.QImageItem.PreserveAspectCrop
                }
            }
            Kirigami.Icon {
                anchors.fill: parent
                visible: !tj.model.image
                source: tj.model.applicationIconName || tj.model.iconName || "preferences-desktop-notification"
            }
        }
        ColumnLayout {
            id: cuerpo
            x: 50; y: 11
            width: tj.width - 50 - 12
            spacing: 1
            RowLayout {
                Layout.fillWidth: true
                T { Layout.fillWidth: true; text: tj.model.applicationName || ""; font.pixelSize: 11; color: root.fg2 }
                T { text: root.cuando(tj.model.updated || tj.model.created); font.pixelSize: 11; color: root.fg2 }
            }
            T { Layout.fillWidth: true; visible: text !== ""; text: tj.model.summary || ""; font.weight: Font.DemiBold }
            T {
                Layout.fillWidth: true
                visible: text !== ""
                text: tj.model.body || ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.85)
            }
        }
        // cerrar, arriba a la izquierda como en macOS
        Rectangle {
            visible: tjHover.hovered && tj.model.closable !== false
            x: -5; y: -5
            width: 20; height: 20; radius: 10
            color: root.dark ? "#4A4A4C" : "#FFFFFF"
            border.width: 1; border.color: root.glassEdge
            T { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; onClicked: historial.close(historial.index(tj.index, 0)) }
        }
    }
}
