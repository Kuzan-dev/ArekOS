pragma Singleton
import QtQuick

// Paleta y medidas tomadas de Ajustes del Sistema de macOS 15 Sequoia.
QtObject {
    id: t

    property bool dark: false
    property color accent: "#007AFF"

    readonly property string font: "Inter"
    readonly property int fontSize: 13
    readonly property int smallSize: 11

    readonly property color windowBg: dark ? "#1E1E1E" : "#F6F6F6"
    readonly property color sidebarBg: dark ? Qt.rgba(0.16, 0.16, 0.17, 0.78) : Qt.rgba(0.90, 0.90, 0.90, 0.80)
    readonly property color sidebarEdge: dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color card: dark ? "#252527" : "#F1F1F1"
    readonly property color separator: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color text: dark ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0, 0, 0, 0.85)
    readonly property color secondary: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.50)
    readonly property color tertiary: dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0, 0, 0, 0.26)
    readonly property color search: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color selection: accent
    readonly property color control: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color controlPressed: dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.14)
    readonly property color switchOff: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color checkOff: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color cardEdge: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color pill: dark ? "#2C2C2E" : "#FFFFFF"
    readonly property color menuBg: dark ? "#2A2A2C" : "#F6F6F6"
    readonly property color destructive: "#FF3B30"

    // Colores de los iconos de la barra lateral (macOS)
    readonly property var tile: ({
        blue: "#0A84FF", green: "#30C759", grey: "#8E8E93", graphite: "#636366",
        black: "#1C1C1E", red: "#FF3B30", pink: "#FF2D55", purple: "#5E5CE6",
        indigo: "#5856D6", orange: "#FF9500", yellow: "#FFCC00", teal: "#32ADE6", cyan: "#30B0C7"
    })

    function refresh() {
        // el modo se deduce del color real de las ventanas: KDE no guarda el nombre del esquema
        // cuando coincide con el del tema global, así que no siempre está en kdeglobals
        const bg = Sys.readConf("kdeglobals", ["Colors:Window"], "BackgroundNormal", "").split(",").map(Number)
        const scheme = Sys.readConf("kdeglobals", ["General"], "ColorScheme", "")
        dark = bg.length >= 3 && !isNaN(bg[0]) ? (0.299 * bg[0] + 0.587 * bg[1] + 0.114 * bg[2]) < 128 : /dark|oscuro/i.test(scheme)
        const acc = Sys.readConf("kdeglobals", ["General"], "AccentColor", "")
        const p = acc.split(",")
        accent = p.length >= 3 ? Qt.rgba(p[0] / 255, p[1] / 255, p[2] / 255, 1) : (dark ? "#0A84FF" : "#007AFF")
    }
}
