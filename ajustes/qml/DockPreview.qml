import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire
import org.kde.kirigami as Kirigami

// Vista previa de las ventanas de una app al dejar el puntero sobre su icono del Dock: miniaturas en
// vivo (PipeWire, como el gestor de tareas de Plasma) con el título; clic para ir a la ventana.
// Es una superficie transparente de pantalla completa: solo la tarjeta recibe el ratón.
Window {
    id: pv
    property var dock
    property string appId: ""
    property point anchorPos: Qt.point(0, 0)     // punto del icono en coordenadas de la pantalla
    readonly property bool hovered: cardHover.hovered
    property int shownCount: 0
    // los modelos agrupado y sin agrupar no escriben igual el id ("app" o "app.desktop")
    function norm(id) { return String(id || "").replace(/\.desktop$/, "") }

    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    title: "vitrum-dock-preview#r" + card.radius   // el radio lo usa el desenfoque de Vitrum (esquinas suavizadas)
    LayerShell.Window.scope: "dock-preview"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    TaskManager.TasksModel {
        id: wins
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: false
        filterByVirtualDesktop: false
        filterByActivity: false
    }
    // cuenta las ventanas de la app (no la visibilidad efectiva, que depende de la propia tarjeta)
    function recount() { let n = 0; for (let i = 0; i < list.count; ++i) if (list.itemAt(i) && list.itemAt(i).matches) n++; shownCount = n }
    onAppIdChanged: Qt.callLater(recount)

    function show(app, pos) {
        appId = app
        anchorPos = pos
        if (!visible) showFullScreen()
        Qt.callLater(place)
    }
    function hide2() { visible = false; appId = "" }
    function place() {
        if (!visible) return
        const e = dock ? dock.position : "bottom"
        const w = card.width, h = card.height
        if (e === "bottom") { card.x = Math.max(8, Math.min(width - w - 8, anchorPos.x - w / 2)); card.y = anchorPos.y - h - 14 }
        else if (e === "left") { card.x = anchorPos.x + 14; card.y = Math.max(8, Math.min(height - h - 8, anchorPos.y - h / 2)) }
        else { card.x = anchorPos.x - w - 14; card.y = Math.max(8, Math.min(height - h - 8, anchorPos.y - h / 2)) }
        Sys.setInputRegion(pv, card.x, card.y, card.width, card.height)
        Sys.setBlur(pv, card.x, card.y, card.width, card.height, card.radius, Material.contrast, 1.0, Material.saturation)
    }

    MacPanel {
        id: card
        width: row.width + 16
        height: row.height + 16
        radius: 12
        visible: pv.shownCount > 0
        onWidthChanged: Qt.callLater(pv.place)
        onHeightChanged: Qt.callLater(pv.place)
        HoverHandler { id: cardHover }

        Row {
            id: row
            x: 8; y: 8
            spacing: 8
            Repeater {
                id: list
                model: wins
                delegate: Item {
                    id: cell
                    required property var model
                    required property int index
                    readonly property bool matches: model.IsWindow === true && pv.norm(model.AppId) === pv.norm(pv.appId)
                    onMatchesChanged: Qt.callLater(pv.recount)
                    Component.onCompleted: Qt.callLater(pv.recount)
                    visible: matches
                    width: matches ? 200 : 0
                    height: matches ? 150 : 0
                    readonly property string uuid: model.WinIdList && model.WinIdList.length ? String(model.WinIdList[0]) : ""

                    Rectangle {
                        id: thumbBox
                        width: 200; height: 124; radius: 8
                        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)
                        border.width: cellHover.hovered ? 2 : 0
                        border.color: Theme.accent
                        clip: true
                        TaskManager.ScreencastingRequest { id: req; uuid: pv.visible && cell.matches ? cell.uuid : "" }
                        PipeWire.PipeWireSourceItem {
                            id: thumb
                            anchors.fill: parent; anchors.margins: 4
                            nodeId: req.nodeId
                            visible: nodeId > 0 && ready
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 48; height: 48
                            visible: !thumb.visible
                            source: cell.model.decoration
                        }
                    }
                    Text {
                        anchors.top: thumbBox.bottom; anchors.topMargin: 6
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: cell.model.display || ""
                        color: Theme.text
                        font.family: Theme.font; font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                    HoverHandler { id: cellHover }
                    TapHandler {
                        onTapped: { wins.requestActivate(wins.makeModelIndex(cell.index)); pv.hide2() }
                    }
                }
            }
        }
    }
}
