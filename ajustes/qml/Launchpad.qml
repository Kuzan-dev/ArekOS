import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami

// Launchpad: cuadrícula de apps a pantalla completa (medidas de macOS a 1080p).
Window {
    id: lp
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "vitrum-launchpad"
    LayerShell.Window.scope: "launchpad"
    // KWin la abre en la pantalla activa (la del puntero) al mostrarla, como macOS
    LayerShell.Window.wantsToBeOnActiveScreen: true
    // misma capa que el dock: el Shell vuelve a mostrar el dock después para que quede encima, como en macOS
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    readonly property real s: height / 1080          // escala respecto a 1080p
    readonly property int cols: 7
    readonly property int rows: 5
    readonly property int perPage: cols * rows
    property var allApps: []
    readonly property var apps: {
        const q = search.text.trim().toLowerCase()
        if (!q) return allApps
        return allApps.filter(a => (a.name + " " + a.generic + " " + a.keywords).toLowerCase().indexOf(q) >= 0)
    }
    readonly property int pages: Math.max(1, Math.ceil(apps.length / perPage))
    property int page: 0
    property bool shown: false

    function toggle() { shown ? close2() : open2() }
    function open2() {
        allApps = Sys.apps()
        search.text = ""; page = 0
        showFullScreen(); shown = true
        Qt.callLater(() => { updateBlur(); search.forceActiveFocus() })
    }
    function close2() { shown = false; hideTimer.restart() }
    function updateBlur() { if (visible) Sys.setBlur(lp, 0, 0, width, height, 0) }
    onWidthChanged: Qt.callLater(updateBlur)
    onHeightChanged: Qt.callLater(updateBlur)
    function launch(a) { Sys.launch(a.id); close2() }
    Timer { id: hideTimer; interval: 180; onTriggered: lp.hide() }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.30)
        opacity: lp.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 170 } }
    }
    Item {
        anchors.fill: parent
        opacity: lp.shown ? 1 : 0
        scale: lp.shown ? 1 : 1.08
        Behavior on opacity { NumberAnimation { duration: 170 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: lp.close2()
            onWheel: (w) => { if (w.angleDelta.y < 0 || w.angleDelta.x < 0) lp.page = Math.min(lp.pages - 1, lp.page + 1); else lp.page = Math.max(0, lp.page - 1) }
        }

        // Buscador
        Rectangle {
            id: field
            width: 250 * lp.s; height: 26 * lp.s; radius: 7 * lp.s
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30 * lp.s
            color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.20)
            Row {
                anchors.centerIn: search.text ? undefined : parent
                x: 10 * lp.s; anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * lp.s
                visible: !search.text
                Magnifier { size: 13 * lp.s; color: Qt.rgba(1, 1, 1, 0.80); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Buscar"; color: Qt.rgba(1, 1, 1, 0.45); font.family: Theme.font; font.pixelSize: 15 * lp.s; anchors.verticalCenter: parent.verticalCenter }
            }
            TextInput {
                id: search
                anchors.fill: parent; anchors.leftMargin: 10 * lp.s; anchors.rightMargin: 10 * lp.s
                verticalAlignment: TextInput.AlignVCenter
                color: "white"; selectionColor: Theme.accent
                font.family: Theme.font; font.pixelSize: 15 * lp.s
                onTextChanged: lp.page = 0
                Keys.onEscapePressed: text ? text = "" : lp.close2()
                Keys.onReturnPressed: if (lp.apps.length) lp.launch(lp.apps[lp.page * lp.perPage])
                Keys.onRightPressed: lp.page = Math.min(lp.pages - 1, lp.page + 1)
                Keys.onLeftPressed: lp.page = Math.max(0, lp.page - 1)
            }
        }

        // Páginas de iconos
        Item {
            id: pagesArea
            anchors { top: field.bottom; topMargin: 30 * lp.s; left: parent.left; right: parent.right; bottom: dots.top; bottomMargin: 20 * lp.s }
            clip: true
            Row {
                x: -lp.page * pagesArea.width
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Repeater {
                    model: lp.pages
                    Item {
                        id: pg
                        required property int index
                        width: pagesArea.width; height: pagesArea.height
                        Grid {
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: lp.cols
                            Repeater {
                                model: lp.apps.slice(pg.index * lp.perPage, (pg.index + 1) * lp.perPage)
                                Item {
                                    required property var modelData
                                    width: 215 * lp.s; height: 174 * lp.s
                                    Kirigami.Icon {
                                        id: ic
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 110 * lp.s; height: width
                                        y: -6 * lp.s
                                        source: modelData.icon || "application-x-executable"
                                        scale: ma.pressed ? 0.92 : 1
                                    }
                                    Text {
                                        anchors.top: ic.bottom; anchors.topMargin: 1 * lp.s
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width - 20 * lp.s
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        color: "white"
                                        font.family: Theme.font; font.pixelSize: 12.5 * lp.s; font.weight: Font.Medium
                                        renderType: Text.NativeRendering
                                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
                                    }
                                    MouseArea { id: ma; anchors.fill: parent; onClicked: lp.launch(modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Puntos de página
        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 120 * lp.s
            spacing: 10 * lp.s
            visible: lp.pages > 1
            Repeater {
                model: lp.pages
                Rectangle {
                    required property int index
                    width: 8 * lp.s; height: width; radius: width / 2
                    color: Qt.rgba(1, 1, 1, index === lp.page ? 0.95 : 0.35)
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: lp.page = index }
                }
            }
        }
    }
}
