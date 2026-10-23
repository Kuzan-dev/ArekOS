import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami

// Icono del Dock: icono, punto de app abierta, rebote al abrirse, ampliación y etiqueta al pasar el ratón.
Item {
    id: di
    property var icon
    property string name: ""
    property string appId: ""
    property bool hasWindows: false
    property bool running: false
    property bool active: false
    property bool starting: false
    signal clicked()
    signal menuRequested(real x, real y)
    readonly property var dock: Window.window
    readonly property bool vertical: dock ? dock.vertical : false
    readonly property string edge: dock ? dock.position : "bottom"

    // centro a lo largo del dock sin ampliar (se fija al entrar el ratón, antes de que cambien los tamaños)
    property real baseCenter: 0
    function captureBase() {
        const r = rowOf()
        if (!r) return
        const p = di.mapToItem(r, di.width / 2, di.height / 2)
        baseCenter = vertical ? p.y : p.x
    }
    function rowOf() { let it = di.parent; while (it && it.objectName !== "dockRow") it = it.parent; return it }
    Connections {
        target: di.dock
        function onHoveringChanged() { if (di.dock.hovering) di.captureBase() }
    }

    readonly property real size: dock ? dock.sizeAt(baseCenter) : 64
    // casilla: el tamaño del icono más 4 px a lo largo del dock (68 px entre iconos con tamaño 64, como en macOS)
    implicitWidth: vertical ? size : size + 4
    implicitHeight: vertical ? size + 4 : size
    width: implicitWidth
    height: implicitHeight

    // El icono se dibuja una sola vez al tamaño máximo y se escala: redibujar el SVG a cada tamaño
    // durante la ampliación era lo que la hacía ir a saltos. Tamaño exacto (sin redondear a 48/64, que
    // dejaba el dibujo en 43 px): los iconos de WhiteSur ocupan el 86 % del lienzo, así que un lienzo
    // del 94 % de la casilla da 52 px de dibujo con tamaño 64, como en macOS.
    readonly property real maxSize: dock ? (dock.magnify ? dock.magSize : dock.tile) : 64
    Kirigami.Icon {
        id: img
        width: Math.round(di.maxSize * 0.94)
        roundToIconSize: false
        height: width
        scale: di.size / di.maxSize
        // el rebote aleja el icono del borde de la pantalla
        x: (parent.width - width) / 2 + (di.edge === "left" ? bounce : di.edge === "right" ? -bounce : 0)
        y: (parent.height - height) / 2 - (di.edge === "bottom" ? bounce : 0)
        source: di.icon
        active: ma.containsMouse
        smooth: true
        property real bounce: 0
        SequentialAnimation on bounce {
            running: di.starting && (!dock || dock.bounce)
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 22; duration: 280; easing.type: Easing.OutQuad }
            NumberAnimation { from: 22; to: 0; duration: 280; easing.type: Easing.InQuad }
            onRunningChanged: if (!running) img.bounce = 0
        }
    }
    // punto de app abierta, entre el icono y el borde de la pantalla
    Rectangle {
        visible: di.running && (!dock || dock.indicators)
        width: 4; height: 4; radius: 2
        // macOS: el punto queda a 4 px del borde de la barra
        x: di.edge === "left" ? -6 : di.edge === "right" ? di.width + 2 : (di.width - width) / 2
        y: di.edge === "bottom" ? di.height + 4 : (di.height - height) / 2
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0, 0, 0, 0.6)
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        function showTip() {
            if (!dock) return
            dock.hoverName = di.name
            // punto del borde interior del icono (hacia el centro de la pantalla)
            dock.hoverPos = di.mapToItem(null, di.edge === "left" ? di.width : di.edge === "right" ? 0 : di.width / 2,
                                         di.edge === "bottom" ? 0 : di.height / 2)
        }
        onContainsMouseChanged: {
            if (!dock) return
            if (containsMouse) {
                showTip()
                dock.hoverHasWindows = di.hasWindows
                dock.hoverApp = di.appId
            } else {
                if (dock.hoverName === di.name) dock.hoverName = ""
                if (dock.hoverApp === di.appId) dock.hoverApp = ""
            }
        }
        // con la ampliación el icono se mueve: la etiqueta lo sigue
        onPositionChanged: if (containsMouse) showTip()
        onClicked: (e) => e.button === Qt.RightButton ? di.menuRequested(e.x, e.y) : di.clicked()
        onPressed: if (dock) { dock.hoverName = ""; dock.hoverApp = "" }
    }
}
