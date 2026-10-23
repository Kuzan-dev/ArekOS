import QtQuick
import org.kde.kirigami as Kirigami

// Icono estilo macOS: cuadrado redondeado con degradado y glifo blanco.
Rectangle {
    id: tile
    property color base: Theme.tile.blue
    property string icon: ""
    property string glyph: ""
    property real size: 20
    width: size
    height: size
    radius: size * 0.27
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(tile.base, 1.18) }
        GradientStop { position: 1; color: tile.base }
    }
    border.width: 0.5
    border.color: Qt.rgba(0, 0, 0, 0.08)

    Kirigami.Icon {
        visible: tile.icon !== ""
        anchors.centerIn: parent
        width: Math.round(tile.size * 0.66)
        height: width
        source: tile.icon
        isMask: true
        color: "white"
    }
    Text {
        visible: tile.glyph !== ""
        anchors.centerIn: parent
        text: tile.glyph
        color: "white"
        font.pixelSize: tile.size * 0.62
        font.bold: true
    }
}
