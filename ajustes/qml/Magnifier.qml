import QtQuick

// Lupa dibujada (como el icono de búsqueda de macOS), escalable y del color que se indique.
Item {
    id: mg
    property real size: 14
    property color color: Theme.secondary
    width: size; height: size
    Rectangle {
        width: mg.size * 0.72; height: width; radius: width / 2
        color: "transparent"; border.width: Math.max(1.2, mg.size * 0.11); border.color: mg.color
    }
    Rectangle {
        x: mg.size * 0.60; y: mg.size * 0.70
        width: mg.size * 0.40; height: Math.max(1.4, mg.size * 0.12); radius: height / 2
        rotation: 45; transformOrigin: Item.Left
        color: mg.color
    }
}
