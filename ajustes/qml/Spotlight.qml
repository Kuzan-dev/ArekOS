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
        const piezas = [[box.x, box.y, box.width, box.height, box.radius]]
        if (lista.visible) piezas.push([lista.x, lista.y, lista.width, lista.height, lista.radius])
        Sys.setBlurRects(sp, piezas, Material.contrast, Material.intensity(box.radius), Material.saturation)
    }
    onWidthChanged: Qt.callLater(updateBlur)
    onHeightChanged: Qt.callLater(updateBlur)

    MouseArea { anchors.fill: parent; onClicked: sp.close2() }

    // como en macOS Tahoe: la barra es una píldora de cristal y los resultados salen en un panel aparte, debajo
    MacPanel {
        id: box
        width: 680
        height: 56
        x: (parent.width - width) / 2
        y: Math.round(parent.height * 0.20)
        radius: 28
        onXChanged: Qt.callLater(sp.updateBlur)
        onYChanged: Qt.callLater(sp.updateBlur)
        MouseArea { anchors.fill: parent }   // no cerrar al hacer clic dentro

        Magnifier { x: 21; anchors.verticalCenter: parent.verticalCenter; size: 20; color: Theme.secondary }
        TextInput {
            id: query
            x: 54; width: parent.width - 54 - 24
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font; font.pixelSize: 22; font.weight: Font.Light
            color: Theme.text; selectionColor: Theme.accent
            Text { visible: !query.text; text: "Búsqueda Spotlight"; color: Theme.tertiary; font: query.font; anchors.verticalCenter: parent.verticalCenter }
            Keys.onEscapePressed: sp.close2()
            Keys.onDownPressed: results.incrementCurrentIndex()
            Keys.onUpPressed: results.decrementCurrentIndex()
            Keys.onReturnPressed: sp.runCurrent()
            Keys.onEnterPressed: sp.runCurrent()
        }
    }

    MacPanel {
        id: lista
        visible: sp.hasQuery && results.count > 0
        width: box.width
        height: Math.min(results.contentHeight + 16, 460)
        x: box.x
        y: box.y + box.height + 8
        radius: 24
        onVisibleChanged: Qt.callLater(sp.updateBlur)
        onHeightChanged: Qt.callLater(sp.updateBlur)
        MouseArea { anchors.fill: parent }

        ListView {
            id: results
            anchors { fill: parent; topMargin: 6; bottomMargin: 10 }
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
            section.property: "category"
            section.delegate: Item {
                required property string section
                width: results.width; height: 26
                Txt { x: 22; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: parent.section; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.secondary }
            }
            delegate: Item {
                id: row
                required property var model
                required property int index
                readonly property bool sel: ListView.isCurrentItem
                width: results.width; height: 36
                Rectangle { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; radius: 10; color: row.sel ? Theme.accent : "transparent" }
                Kirigami.Icon { id: ri; x: 20; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; source: row.model.decoration }
                Txt {
                    anchors.left: ri.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.StyledText
                    text: row.model.display + (row.model.subtext ? "<font color='" + (row.sel ? "#D8E6FF" : Theme.secondary) + "'> — " + row.model.subtext + "</font>" : "")
                    color: row.sel ? "white" : Theme.text
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: results.currentIndex = row.index
                    onClicked: sp.runCurrent()
                }
            }
        }
    }
    function runCurrent() {
        if (results.count === 0) return
        if (rmodel.run(rmodel.index(results.currentIndex, 0))) close2()
    }
}
