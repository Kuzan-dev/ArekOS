import QtQuick

Canvas {
    property bool pointLeft: false
    property color tint: Theme.tertiary
    width: 8; height: 13
    onTintChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"); c.reset()
        c.strokeStyle = tint; c.lineWidth = 1.8; c.lineCap = "round"; c.lineJoin = "round"
        c.beginPath()
        if (pointLeft) { c.moveTo(6.5, 1.5); c.lineTo(1.5, 6.5); c.lineTo(6.5, 11.5) }
        else { c.moveTo(1.5, 1.5); c.lineTo(6.5, 6.5); c.lineTo(1.5, 11.5) }
        c.stroke()
    }
}
