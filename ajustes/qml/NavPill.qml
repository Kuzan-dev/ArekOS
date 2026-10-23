import QtQuick
import QtQuick.Effects

Item {
    id: np
    property bool canBack: false
    property bool canForward: false
    signal backClicked()
    signal forwardClicked()
    width: 60; height: 28
    Rectangle {
        id: pillBg
        anchors.fill: parent
        radius: height / 2
        color: Theme.pill
        border.width: 0.5
        border.color: Theme.separator
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowOpacity: Theme.dark ? 0.5 : 0.12; shadowBlur: 0.5; shadowVerticalOffset: 1 }
    }
    Chevron { pointLeft: true; x: 12; anchors.verticalCenter: parent.verticalCenter; tint: np.canBack ? Theme.text : Theme.tertiary }
    Rectangle { x: parent.width / 2; width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Theme.separator }
    Chevron { x: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; tint: np.canForward ? Theme.text : Theme.tertiary }
    MouseArea { width: parent.width / 2; height: parent.height; onClicked: np.backClicked() }
    MouseArea { x: parent.width / 2; width: parent.width / 2; height: parent.height; onClicked: np.forwardClicked() }
}
