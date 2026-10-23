import QtQuick

// Superficie translúcida de macOS (Centro de Control, Spotlight, vista previa del Dock…), con el borde medido
// en Monterey: sombra negra al 24 % (σ 19 px), contorno exterior de 1 px, filo interior blanco de 1 px y la capa
// del material. El desenfoque lo pone KWin detrás: la ventana llama a Sys.setBlur con la geometría del panel
// (blurRect) cada vez que cambia.
Item {
    id: mp
    property real radius: 15
    default property alias content: inner.data
    readonly property rect blurRect: Qt.rect(x, y, width, height)

    BorderImage {
        anchors.fill: parent
        anchors.margins: -60
        border { left: 79; top: 79; right: 79; bottom: 79 }
        source: "sombra-dock.png"
        smooth: true
    }
    MaterialEdge {
        anchors.fill: parent
        radius: mp.radius
        fill: Material.tintColor
        outline: Material.outline
        highlight: Material.highlight
    }
    Item { id: inner; anchors.fill: parent }
}
