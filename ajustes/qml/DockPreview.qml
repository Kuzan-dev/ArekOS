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
    // siempre en la pantalla del dock (si no, con varios monitores el compositor la ponía en otro)
    LayerShell.Window.screenConfiguration: LayerShell.Window.ScreenFromQWindow

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
        // la superficie se crea en la pantalla del dock (cambiarla con la ventana visible exige recrearla)
        if (dock && dock.screen && screen !== dock.screen) { visible = false; screen = dock.screen }
        // con la geometría de esa pantalla (showFullScreen la recolocaba según la posición: la primera pantalla)
        if (!visible) {
            const sc = screen
            // según de dónde venga, la pantalla es un QScreen (geometry) o un Screen de QML (virtualX…)
            const g = sc ? (sc.geometry !== undefined ? sc.geometry : Qt.rect(sc.virtualX, sc.virtualY, sc.width, sc.height)) : null
            if (g) { x = g.x; y = g.y; width = g.width; height = g.height }
            visible = true
        }
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
        Sys.setBlur(pv, card.x, card.y, card.width, card.height, card.radius, Material.contrast, Material.intensity(card.radius), Material.saturation)
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
                        opacity: cell.model.IsMinimized === true ? 0.55 : 1   // minimizada: atenuada
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
                            // visible en cuanto hay flujo: «ready» solo llega tras pintar el primer fotograma, y
                            // oculto nunca lo pintaba (la vista previa se quedaba en el icono)
                            visible: nodeId > 0
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 48; height: 48
                            visible: !thumb.visible || !thumb.ready
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
                    // cerrar, minimizar y maximizar esa ventana: barra de tres segmentos con los colores del semáforo,
                    // a todo el ancho de la miniatura (arriba o abajo según Ajustes); aparece al pasar el puntero
                    Row {
                        id: seg
                        z: 3
                        readonly property bool atTop: pv.dock && pv.dock.previewButtons === "arriba"
                        x: thumbBox.x + 6
                        y: atTop ? thumbBox.y + 6 : thumbBox.y + thumbBox.height - height - 6
                        width: thumbBox.width - 12
                        height: 22
                        spacing: 2
                        visible: cellHover.hovered
                        Repeater {
                            model: [
                                { fill: "#FF5F57", glyph: "#4D0000", act: "cerrar", name: "Cerrar" },
                                { fill: "#FEBC2E", glyph: "#6B3D00", act: "minimizar", name: "Minimizar" },
                                { fill: "#28C840", glyph: "#004D00", act: "maximizar", name: "Maximizar" }
                            ]
                            Rectangle {
                                id: sb
                                required property var modelData
                                required property int index
                                width: (seg.width - 2 * seg.spacing) / 3
                                height: seg.height
                                // media píldora: redondeados solo los extremos de la barra
                                topLeftRadius: index === 0 ? 11 : 3
                                bottomLeftRadius: index === 0 ? 11 : 3
                                topRightRadius: index === 2 ? 11 : 3
                                bottomRightRadius: index === 2 ? 11 : 3
                                color: sbMa.pressed ? Qt.darker(modelData.fill, 1.18) : (sbMa.containsMouse ? Qt.lighter(modelData.fill, 1.08) : modelData.fill)
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.name
                                Canvas {
                                    anchors.centerIn: parent
                                    width: 12; height: 12
                                    onPaint: {
                                        const g = getContext("2d")
                                        g.reset()
                                        g.strokeStyle = sb.modelData.glyph; g.fillStyle = sb.modelData.glyph
                                        g.lineWidth = 1.7; g.lineCap = "round"
                                        if (sb.index === 0) {
                                            g.beginPath(); g.moveTo(3, 3); g.lineTo(9, 9); g.moveTo(9, 3); g.lineTo(3, 9); g.stroke()
                                        } else if (sb.index === 1) {
                                            g.beginPath(); g.moveTo(2, 6); g.lineTo(10, 6); g.stroke()
                                        } else {
                                            g.beginPath(); g.moveTo(2.5, 2.5); g.lineTo(8, 2.5); g.lineTo(2.5, 8); g.closePath(); g.fill()
                                            g.beginPath(); g.moveTo(9.5, 9.5); g.lineTo(4, 9.5); g.lineTo(9.5, 4); g.closePath(); g.fill()
                                        }
                                    }
                                }
                                MouseArea {
                                    id: sbMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        const ix = wins.makeModelIndex(cell.index)
                                        if (sb.modelData.act === "cerrar") wins.requestClose(ix)
                                        else if (sb.modelData.act === "minimizar") wins.requestToggleMinimized(ix)
                                        else { wins.requestToggleMaximized(ix); wins.requestActivate(ix); pv.hide2() }
                                    }
                                }
                            }
                        }
                    }
                    TapHandler {
                        onTapped: { wins.requestActivate(wins.makeModelIndex(cell.index)); pv.hide2() }
                    }
                }
            }
        }
    }
}
