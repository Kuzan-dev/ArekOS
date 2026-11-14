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

    // la sombra va recortada por dentro con la forma del panel: una con otro radio dejaría un hueco sin sombra fuera
    // de las esquinas (un halo claro). Hay una por radio (herramientas/sombra-dock.py); se usa la más cercana.
    readonly property var radiosSombra: [12, 15, 18, 19, 24, 28, 30]
    readonly property int radioSombra: radiosSombra.reduce((a, b) => Math.abs(b - radius) < Math.abs(a - radius) ? b : a)
    BorderImage {
        anchors.fill: parent
        anchors.margins: -60
        readonly property int borde: 60 + mp.radioSombra
        border { left: borde; top: borde; right: borde; bottom: borde }
        source: mp.radioSombra === 19 ? "sombra-dock.png" : "sombra-r" + mp.radioSombra + ".png"
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
