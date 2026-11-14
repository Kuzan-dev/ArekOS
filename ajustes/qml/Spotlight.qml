import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

// Spotlight con el motor de KRunner (Milou), con el aspecto de macOS Tahoe.
Window {
    id: sp
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "vitrum-spotlight#r" + box.radius   // el radio lo usa el desenfoque de Vitrum (esquinas suavizadas)
    LayerShell.Window.scope: "spotlight"
    // KWin la abre en la pantalla activa (la del puntero) al mostrarla, como macOS
    LayerShell.Window.wantsToBeOnActiveScreen: true
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    readonly property bool hasQuery: query.text.trim() !== ""
    function toggle() { visible ? close2() : open2() }
    function open2() {
        Theme.refresh()
        query.text = ""
        showFullScreen()
        Qt.callLater(() => { query.forceActiveFocus(); updateBlur() })
    }
    function close2() { hide(); query.text = "" }
    function search(text) { if (!visible) open2(); query.text = text }
    function updateBlur() {
        if (!visible) return
        Sys.setBlur(sp, box.x, box.y, box.width, box.height, box.radius, Material.contrast, Material.intensity(box.radius), Material.saturation)
    }
    onWidthChanged: Qt.callLater(updateBlur)
    onHeightChanged: Qt.callLater(updateBlur)

    MouseArea { anchors.fill: parent; onClicked: sp.close2() }

    // como en macOS Tahoe: vacía es una píldora de cristal; al escribir crece hacia abajo en un solo panel con el
    // campo arriba, una fila de filtros por categoría y la lista de resultados (filas de 48 px con el detalle debajo)
    readonly property bool abierto: hasQuery && results.count > 0
    readonly property real alturaLista: Math.min(results.contentHeight, 9 * 48)
    MacPanel {
        id: box
        width: 680
        height: sp.abierto ? 56 + 1 + 44 + sp.alturaLista + 10 : 56
        x: (parent.width - width) / 2
        y: Math.round(parent.height * 0.20)
        radius: 28
        onXChanged: Qt.callLater(sp.updateBlur)
        onYChanged: Qt.callLater(sp.updateBlur)
        onHeightChanged: Qt.callLater(sp.updateBlur)
        MouseArea { anchors.fill: parent }   // no cerrar al hacer clic dentro

        Magnifier { x: 21; y: (56 - height) / 2; size: 20; color: Theme.secondary }
        TextInput {
            id: query
            x: 54; width: parent.width - 54 - 24
            height: 56
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.font; font.pixelSize: 22; font.weight: Font.Light
            color: Theme.text; selectionColor: Theme.accent
            Text { visible: !query.text; text: "Búsqueda Spotlight"; color: Theme.tertiary; font: query.font; anchors.verticalCenter: parent.verticalCenter }
            Keys.onEscapePressed: sp.close2()
            Keys.onDownPressed: results.incrementCurrentIndex()
            Keys.onUpPressed: results.decrementCurrentIndex()
            Keys.onTabPressed: sp.siguienteCategoria(1)
            Keys.onBacktabPressed: sp.siguienteCategoria(-1)
            Keys.onReturnPressed: sp.runCurrent()
            Keys.onEnterPressed: sp.runCurrent()
        }
        Rectangle { visible: sp.abierto; x: 18; y: 56; width: parent.width - 36; height: 1; color: Theme.separator }

        // filtros: las categorías que hay en los resultados; al pulsar una se salta a su primer resultado
        Instantiator {
            id: filas
            model: rmodel
            delegate: QtObject { readonly property string cat: model.category }
            // objectAt no avisa de cambios: rev obliga a recalcular las categorías
            property int rev: 0
            onObjectAdded: rev++
            onObjectRemoved: rev++
        }
        readonly property var categorias: {
            filas.rev
            const out = []
            for (let i = 0; i < filas.count; i++) { const f = filas.objectAt(i); if (f && out.indexOf(f.cat) < 0) out.push(f.cat) }
            return out
        }
        readonly property string actual: results.currentItem ? results.currentItem.model.category : ""
        Flickable {
            visible: sp.abierto
            x: 14; y: 57; width: parent.width - 28; height: 44
            contentWidth: chips.width; clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: chips
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: box.categorias
                    Rectangle {
                        required property string modelData
                        readonly property bool sel: modelData === box.actual
                        height: 28; radius: 14
                        width: chipTxt.implicitWidth + 26
                        color: sel ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12))
                                   : chipHover.hovered ? Theme.controlPressed : Theme.control
                        HoverHandler { id: chipHover }
                        Txt { id: chipTxt; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; onClicked: sp.irACategoria(parent.modelData) }
                    }
                }
            }
        }

        ListView {
            id: results
            visible: sp.abierto
            x: 0; y: 56 + 1 + 44
            width: parent.width; height: sp.alturaLista
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            onCountChanged: if (count > 0 && currentIndex < 0) currentIndex = 0
            model: Milou.ResultsModel {
                id: rmodel
                queryString: query.text
                limit: 25
                onModelReset: results.currentIndex = 0
                onRowsInserted: if (results.currentIndex < 0) results.currentIndex = 0
            }
            delegate: Item {
                id: row
                required property var model
                required property int index
                readonly property bool sel: ListView.isCurrentItem
                width: results.width; height: 48
                // selección de Tahoe: cristal claro, no el color de acento
                Rectangle {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; radius: 12
                    color: row.sel ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"
                }
                Kirigami.Icon { id: ri; x: 22; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; source: row.model.decoration }
                Column {
                    anchors.left: ri.right; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { width: parent.width; text: row.model.display; font.pixelSize: 15 }
                    Txt { width: parent.width; visible: !!row.model.subtext; text: row.model.subtext || ""; font.pixelSize: 12; color: Theme.secondary }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: results.currentIndex = row.index
                    onClicked: sp.runCurrent()
                }
            }
        }
    }
    function irACategoria(cat) {
        for (let i = 0; i < filas.count; i++) {
            const f = filas.objectAt(i)
            if (f && f.cat === cat) { results.currentIndex = i; results.positionViewAtIndex(i, ListView.Beginning); return }
        }
    }
    // Tab y Mayús+Tab pasan a la categoría siguiente o anterior
    function siguienteCategoria(paso) {
        const c = box.categorias
        if (c.length === 0) return
        const i = c.indexOf(box.actual)
        irACategoria(c[(i + paso + c.length) % c.length])
    }
    function runCurrent() {
        if (results.count === 0) return
        if (rmodel.run(rmodel.index(results.currentIndex, 0))) close2()
    }
}
