import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import org.kde.layershell as LayerShell
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.kquickcontrolsaddons as KQuickAddons

// Centro de Notificaciones de la barra de menús, como en macOS Tahoe: la campana abre las notificaciones en
// tarjetas sueltas, sin panel de fondo y con el escritorio ligeramente oscurecido alrededor, como el Centro de
// Control de vitrum-shell; la letra es la de los menús de Wi‑Fi y Sonido. Va dentro de plasmashell porque el
// historial vive ahí; la campana de KDE sigue cargada en un panel escondido (vitrum-disposicion, paso 4) porque es
// la que muestra las notificaciones emergentes.
// El popup de Plasma siempre dibuja su fondo (AppletPopup no respeta backgroundHints), así que se abre una ventana
// propia de layer-shell. Desde QML no se puede pedir desenfoque a KWin: las tarjetas son de cristal más opaco.
PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property string bin: "$HOME/.local/bin/"

    property date now: new Date()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = new Date() }

    // ── Colores: tarjetas de cristal sin desenfoque detrás, más opacas que las del Centro de Control ──
    readonly property color fg: Kirigami.Theme.textColor
    readonly property bool dark: (fg.r + fg.g + fg.b) / 3 > 0.5
    readonly property color fg2: Qt.rgba(fg.r, fg.g, fg.b, 0.6)
    readonly property color glass: dark ? Qt.rgba(0.16, 0.16, 0.19, 0.86) : Qt.rgba(0.97, 0.97, 0.98, 0.88)
    readonly property color glassHover: dark ? Qt.rgba(0.21, 0.21, 0.24, 0.90) : Qt.rgba(1, 1, 1, 0.94)
    readonly property color glassEdge: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)

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
    function abrir2() { now = new Date(); Plasmoid.configuration.lastRead = now; centro.showFullScreen(); veloIn.restart() }
    function cerrar() { centro.hide() }
    function alternar() { centro.visible ? cerrar() : abrir2() }
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
        onClicked: root.alternar()
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: 26; height: 20; radius: 10
            color: compacto.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.28)
                 : centro.visible ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2) : "transparent"
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

    // sin vista completa Plasma no muestra la compacta en la barra (el calendario/las notificaciones se abren aparte)
    fullRepresentation: Item {}

    // ── Centro de Notificaciones ─────────────────────────────────────────────
    // superficie transparente de pantalla completa (un clic fuera de las tarjetas la cierra), como el Centro de
    // Control: las tarjetas a 6 px de la barra y del borde derecho
    Window {
        id: centro
        visible: false
        color: "transparent"
        flags: Qt.FramelessWindowHint
        title: "vitrum-notificaciones"
        LayerShell.Window.scope: "vitrum-notificaciones"
        LayerShell.Window.wantsToBeOnActiveScreen: true
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

        MouseArea { anchors.fill: parent; onClicked: root.cerrar() }
        Item { focus: centro.visible; Keys.onEscapePressed: root.cerrar() }
        // el mismo oscurecimiento ligero que el Centro de Control, centrado en las tarjetas
        GE.RadialGradient {
            anchors.fill: parent
            horizontalOffset: lista.x + lista.width / 2 - width / 2
            verticalOffset: lista.y + Math.min(lista.height, 500) * 0.4 - height / 2
            horizontalRadius: 620
            verticalRadius: 760
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.26) }
                GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0, 0.20) }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.11) }
                GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.04) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on opacity { id: veloIn; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic; running: false }
        }

        Flickable {
            id: lista
            width: 340
            x: centro.width - 6 - width
            y: 32 + 6
            height: Math.min(contenido.implicitHeight + 8, centro.height - y - 80)
            contentHeight: contenido.implicitHeight + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            MouseArea { width: lista.width; height: Math.max(lista.height, lista.contentHeight) }   // los clics entre tarjetas no cierran
            ColumnLayout {
                id: contenido
                x: 0; y: 6
                width: parent.width
                spacing: 10

                // cabecera directamente sobre el escritorio, con sombra para que se lea, como en Tahoe
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.preferredHeight: 26
                    visible: historial.count > 0
                    Sombreado { text: "Notificaciones"; font.weight: Font.Bold; Layout.fillWidth: true }
                    Pildora { texto: "Borrar todo"; onPulsada: root.borrarTodo() }
                }

                // sin notificaciones: el texto suelto de Tahoe («Sin notificaciones recientes»)
                Sombreado {
                    visible: historial.count === 0
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 14
                    text: root.noMolestar ? "No molestar activado" : "Sin notificaciones recientes"
                    font.pixelSize: 15; font.weight: Font.DemiBold
                }

                Repeater {
                    model: historial
                    delegate: Tarjeta {}
                }

                // como «Editar widgets» de Tahoe
                Pildora {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    texto: "Ajustes de notificaciones…"
                    onPulsada: { root.abrir(root.bin + "vitrum-ajustes notificaciones"); root.cerrar() }
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

    // texto suelto sobre el escritorio, con sombra
    component Sombreado: T {
        color: root.dark ? "white" : "#1D1D1F"
        layer.enabled: true
        layer.effect: GE.DropShadow { radius: 6; samples: 13; verticalOffset: 1; color: root.dark ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(1, 1, 1, 0.7) }
    }
    // botón en píldora de cristal («Borrar todo», «Ajustes de notificaciones…»)
    component Pildora: Rectangle {
        id: pd
        property string texto: ""
        signal pulsada()
        implicitWidth: pdTxt.implicitWidth + 26; implicitHeight: 26; radius: 13
        color: pdMa.containsMouse ? root.glassHover : root.glass
        border.width: 1; border.color: root.glassEdge
        T { id: pdTxt; anchors.centerIn: parent; text: pd.texto; font.pixelSize: 12; color: pdMa.containsMouse ? root.fg : root.fg2 }
        MouseArea { id: pdMa; anchors.fill: parent; hoverEnabled: true; onClicked: pd.pulsada() }
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
        radius: 22
        color: tjHover.hovered ? root.glassHover : root.glass
        border.width: 1; border.color: root.glassEdge
        HoverHandler { id: tjHover }
        MouseArea {
            anchors.fill: parent
            enabled: !!tj.model.hasDefaultAction
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: { historial.invokeDefaultAction(historial.index(tj.index, 0), NotificationManager.Notifications.Close); root.cerrar() }
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
