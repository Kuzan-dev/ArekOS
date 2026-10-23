pragma Singleton
import QtQuick

// Material translúcido de macOS medido en Monterey (dock sobre un fondo de prueba, con y sin dock):
//   oscuro → desenfoque σ≈30, saturación ×1,57, brillo ×0,56, +0,09 de gris
//   claro  → desenfoque σ≈30, saturación ×1,68, brillo ×0,59, +0,36 de gris
// En KWin: desenfoque de fuerza 10 + efecto de contraste (saturación y contraste) + una capa negra o blanca
// encima. KWin ignora la "intensidad", por eso el brillo lo pone la capa. Recalibrable en vitrumrc [Material].
QtObject {
    readonly property bool d: Theme.dark
    function conf(k, def) { return Number(Sys.readConf("vitrumrc", ["Material"], k, def)) }
    readonly property real tint: d ? conf("DockTintDark", "0.26") : conf("DockTintLight", "0.36")
    readonly property color tintColor: d ? Qt.rgba(0, 0, 0, tint) : Qt.rgba(1, 1, 1, tint)
    readonly property real contrast: d ? conf("ContrastDark", "0.757") : conf("ContrastLight", "0.972")
    readonly property real saturation: d ? conf("SaturationDark", "1.63") : conf("SaturationLight", "1.74")
    // borde medido: filo interior blanco al 15 %, contorno exterior negro al 25,6 % / 7 %, sombra σ19 al 24 %
    // (MaterialEdge los dibuja con cobertura exacta, así que son los valores medidos tal cual)
    // (valores de dibujo ajustados midiendo la pantalla con el mismo fondo que la Mac)
    readonly property color highlight: Qt.rgba(1, 1, 1, 0.17)
    readonly property color outline: Qt.rgba(0, 0, 0, d ? 0.28 : 0.08)
}
