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
    // Con el desenfoque de Vitrum cargado, la capa negra/blanca y el filo los aplica el propio efecto, en el
    // mismo espacio de color que macOS (gamma), y no KWin al mezclar la ventana: en HDR KWin mezcla en luz
    // lineal y la capa y el filo se veían grisáceos y brillantes. Viajan en la "intensidad" del efecto de
    // contraste: 10 × radio de esquina + tinte (< 1 capa negra, > 1 capa blanca); ver vitrumTint en
    // kwin-desenfoque/blur.cpp. Sin el efecto (p. ej. tras actualizar KWin), los pinta QML.
    property bool fx: Sys.effectLoaded("vitrumblur")
    property Timer fxCheck: Timer { interval: 15000; running: true; repeat: true; onTriggered: fx = Sys.effectLoaded("vitrumblur") }
    function intensity(radius) { return fx ? 10 * Math.round(radius) + (d ? 1 - tint : 1 + tint) : 1.0 }
    readonly property color tintColor: fx ? "transparent" : d ? Qt.rgba(0, 0, 0, tint) : Qt.rgba(1, 1, 1, tint)
    readonly property real contrast: d ? conf("ContrastDark", "0.813") : conf("ContrastLight", "0.972")
    readonly property real saturation: d ? conf("SaturationDark", "1.54") : conf("SaturationLight", "1.74")
    // borde medido: filo interior blanco al 15 %, contorno exterior negro al 25,6 % / 7 %, sombra σ19 al 24 %
    // (MaterialEdge los dibuja con cobertura exacta, así que son los valores medidos tal cual)
    // (valores de dibujo ajustados midiendo la pantalla con el mismo fondo que la Mac)
    readonly property color highlight: fx ? "transparent" : Qt.rgba(1, 1, 1, 0.17)
    readonly property color outline: Qt.rgba(0, 0, 0, d ? 0.28 : 0.08)
}
