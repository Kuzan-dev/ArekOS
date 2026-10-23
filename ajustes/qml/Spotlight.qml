import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

// Spotlight con el motor de KRunner (Milou), con el aspecto de macOS Sequoia.
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
    function updateBlur() { if (visible) Sys.setBlur(sp, box.x, box.y, box.width, box.height, box.radius, Material.contrast, 1.0, Material.saturation) }
    onWidthChanged: Qt.callLater(updateBlur)
    onHeightChanged: Qt.callLater(updateBlur)

    MouseArea { anchors.fill: parent; onClicked: sp.close2() }

    MacPanel {
        id: box
        width: 680
        height: 52 + (sp.hasQuery && results.count ? Math.min(results.contentHeight + 12, 440) + 1 : 0)
        x: (parent.width - width) / 2
        y: Math.round(parent.height * 0.20)
        radius: 12
        onHeightChanged: Qt.callLater(sp.updateBlur)
        onXChanged: Qt.callLater(sp.updateBlur)
        onYChanged: Qt.callLater(sp.updateBlur)
        MouseArea { anchors.fill: parent }   // no cerrar al hacer clic dentro

        // Barra de búsqueda
        Item {
            id: bar
            width: parent.width; height: 52
            Magnifier { x: 17; anchors.verticalCenter: parent.verticalCenter; size: 20; color: Theme.secondary }
            TextInput {
                id: query
                x: 48; width: parent.width - 64
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
        Rectangle { visible: sp.hasQuery && results.count > 0; y: 52; width: parent.width; height: 1; color: Theme.separator }

        ListView {
            id: results
            visible: sp.hasQuery
            anchors { top: bar.bottom; topMargin: 7; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 5 }
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
                width: results.width; height: 24
                Txt { x: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: parent.section; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.secondary }
            }
            delegate: Item {
                id: row
                required property var model
                required property int index
                readonly property bool sel: ListView.isCurrentItem
                width: results.width; height: 28
                Rectangle { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; radius: 6; color: row.sel ? Theme.accent : "transparent" }
                Kirigami.Icon { id: ri; x: 18; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; source: row.model.decoration }
                Txt {
                    anchors.left: ri.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 18
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
