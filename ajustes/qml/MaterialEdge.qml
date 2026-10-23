import QtQuick
import QtQuick.Shapes

// Relleno del material + contorno exterior de 1 px + filo interior de 1 px, con cobertura exacta por píxel
// (renderizador de curvas de Qt) y esquina continua de macOS (NSBezierPath(roundedRect:), superelipse p≈2,8:
// Bézier cúbica con alcance r×1,36 y puntos de control a 0,70 del vértice).
// El suavizado de Rectangle repartía medio píxel a cada lado del borde y su arco circular tenía un salto de
// curvatura al unirse al tramo recto; aquí la transición es continua y cada fila recibe solo lo suyo, como en macOS.
Item {
    id: me
    property real radius: 19
    property color fill: "transparent"
    property color outline: "transparent"     // fuera del borde, [-1, 0]
    property color highlight: "transparent"   // dentro del borde, [0, 1]

    component ContinuousBox : ShapePath {
        property real bx: 0
        property real by: 0
        property real bw: me.width
        property real bh: me.height
        property real br: me.radius
        // alcance de la esquina continua (1,36 × radio nominal; acotado a la mitad del lado menor)
        readonly property real cr: Math.min(Math.max(0, br) * 1.36, Math.min(bw, bh) / 2)
        // distancia de los puntos de control al vértice de la esquina (1 - 0,70 = 0,30)
        readonly property real cp: cr * 0.30

        startX: bx + cr
        startY: by
        PathLine { x: bx + bw - cr; y: by }
        PathCubic {
            control1X: bx + bw - cp; control1Y: by
            control2X: bx + bw;      control2Y: by + cp
            x: bx + bw;              y: by + cr
        }
        PathLine { x: bx + bw; y: by + bh - cr }
        PathCubic {
            control1X: bx + bw;      control1Y: by + bh - cp
            control2X: bx + bw - cp; control2Y: by + bh
            x: bx + bw - cr;         y: by + bh
        }
        PathLine { x: bx + cr; y: by + bh }
        PathCubic {
            control1X: bx + cp; control1Y: by + bh
            control2X: bx;      control2Y: by + bh - cp
            x: bx;              y: by + bh - cr
        }
        PathLine { x: bx; y: by + cr }
        PathCubic {
            control1X: bx;      control1Y: by + cp
            control2X: bx + cp; control2Y: by
            x: bx + cr;         y: by
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // relleno: exactamente la esquina continua
        ContinuousBox {
            strokeWidth: -1
            fillColor: me.fill
        }
        // contorno: trazo de 1 px centrado medio píxel por fuera
        ContinuousBox {
            fillColor: "transparent"
            strokeColor: me.outline
            strokeWidth: 1
            bx: -0.5; by: -0.5; bw: me.width + 1; bh: me.height + 1; br: me.radius + 0.5
        }
        // filo: trazo de 1 px centrado medio píxel por dentro
        ContinuousBox {
            fillColor: "transparent"
            strokeColor: me.highlight
            strokeWidth: 1
            bx: 0.5; by: 0.5; bw: me.width - 1; bh: me.height - 1; br: Math.max(0, me.radius - 0.5)
        }
    }
}
