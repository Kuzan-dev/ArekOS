import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.volume as Vol
import org.kde.kirigami as Kirigami

// Iconos de Wi‑Fi y Sonido de la barra de menús, como en macOS: muestran la señal y el volumen, y cada uno abre
// su menú bajo el icono. El menú es la vista de detalle del Centro de Control de vitrum-shell (ControlCenter.qml).
// Cuáles se ven se elige en Ajustes → Barra de menús (vitrumrc, grupo BarraMenus).
PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property var st: ({ show_wifi: "true", show_sonido: "true" })
    readonly property bool showWifi: st.show_wifi !== "false"
    readonly property bool showSonido: st.show_sonido !== "false"
    readonly property string bin: "$HOME/.local/bin/"

    // menú abierto ("wifi", "sonido" o ""): su icono se resalta con una píldora, como en macOS Tahoe. Se marca al
    // pulsar y, mientras siga abierto, se pregunta a vitrum-shell (org.vitrum.Shell.Abierto) hasta que se cierre
    property string abierto: ""
    property real pulsado: 0
    Timer {
        id: vigila
        interval: 300; repeat: true
        onTriggered: root.run("dbus-send --session --print-reply=literal --dest=org.vitrum.Shell /Shell org.vitrum.Shell.Abierto")
    }

    P5Support.DataSource {
        id: sh
        engine: "executable"
        onNewData: (source, data) => {
            if (source.indexOf("org.vitrum.Shell.Abierto") >= 0) {
                // la respuesta puede llegar antes de que vitrum-shell procese el clic: se ignora el primer instante
                if (Date.now() - root.pulsado > 500) {
                    root.abierto = (data.stdout || "").trim()
                    if (root.abierto === "") vigila.stop()
                }
            } else if (source.indexOf("vitrum-barra-estado") >= 0) {
                const s = {}
                for (const line of (data.stdout || "").split("\n")) { const i = line.indexOf("="); if (i > 0) s[line.slice(0, i)] = line.slice(i + 1) }
                root.st = s
            }
            disconnectSource(source)
        }
    }
    function run(cmd) { sh.connectSource(cmd + " #" + Date.now()) }
    // las apps se abren en su propio grupo de procesos (scope de systemd): si cuelgan de plasmashell, Plasma las
    // cierra al reiniciarse (y con ellas lo que estuvieran haciendo, como aplicar una opción de la barra)
    function abrir(cmd) { run("setsid -f systemd-run --user --scope --collect --quiet " + cmd) }
    Timer { interval: 3000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.run(root.bin + "vitrum-barra-estado") }

    function menu(view, item) {
        abierto = abierto === view ? "" : view
        pulsado = Date.now()
        vigila.restart()
        const p = item.mapToGlobal(0, 0)
        run("dbus-send --session --type=method_call --dest=org.vitrum.Shell /Shell org.vitrum.Shell.ControlCenterMenu string:" + view + " int32:" + Math.round(p.x))
    }

    // Wi‑Fi: abanico de tres partes; las que no llegan con la señal actual quedan en gris
    readonly property bool hayWifi: st.wifi_dev !== undefined && st.wifi_dev !== "" && st.wifi_dev !== "unavailable"
    readonly property bool wifiOn: st.wifi_on === "enabled"
    readonly property bool wifiConectado: st.wifi_dev === "connected"
    readonly property int senal: !wifiConectado ? 0 : Number(st.signal || 0) >= 67 ? 3 : Number(st.signal || 0) >= 34 ? 2 : 1

    // Sonido: el dispositivo de salida de Plasma (al instante, sin consultar pactl)
    readonly property var sink: Vol.PreferredDevice.sink
    readonly property real nivel: sink ? sink.volume / 65536 : 0
    readonly property bool mudo: !sink || sink.muted
    readonly property int ondas: mudo || nivel <= 0.005 ? 0 : nivel < 0.34 ? 1 : nivel < 0.67 ? 2 : 3
    function cambiarVolumen(paso) {
        if (!sink) return
        if (paso > 0 && sink.muted) sink.muted = false
        sink.volume = Math.round(Math.max(0, Math.min(1, nivel + paso)) * 65536)
    }

    compactRepresentation: RowLayout {
        spacing: 0
        // mismo paso que los iconos de la bandeja y el Centro de Control: 30 px entre centros
        readonly property int itemWidth: 30
        Layout.preferredWidth: (root.showWifi ? itemWidth : 0) + (root.showSonido ? itemWidth : 0)
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth

        BarButton {
            id: wifiBtn
            visible: root.showWifi
            abierto: root.abierto === "wifi"
            onClicked: root.hayWifi ? root.menu("wifi", wifiBtn) : root.abrir(root.bin + "vitrum-ajustes red")
            Kirigami.Icon {
                visible: !root.hayWifi
                anchors.centerIn: parent
                width: 16; height: 16
                source: "network-wired-symbolic"; isMask: true; color: Kirigami.Theme.textColor
            }
            Shape {
                id: wifi
                visible: root.hayWifi
                anchors.centerIn: parent
                width: 18; height: 14
                preferredRendererType: Shape.CurveRenderer
                readonly property real cx: 9
                readonly property real cy: 13
                function tono(parte) { return root.wifiConectado && parte <= root.senal ? Kirigami.Theme.textColor
                                                                       : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3) }
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: wifi.tono(1)
                    startX: wifi.cx; startY: wifi.cy
                    PathAngleArc { centerX: wifi.cx; centerY: wifi.cy; radiusX: 3.4; radiusY: 3.4; startAngle: -135; sweepAngle: 90; moveToStart: false }
                    PathLine { x: wifi.cx; y: wifi.cy }
                }
                ShapePath {
                    strokeColor: wifi.tono(2); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: wifi.cx; centerY: wifi.cy; radiusX: 6.3; radiusY: 6.3; startAngle: -135; sweepAngle: 90 }
                }
                ShapePath {
                    strokeColor: wifi.tono(3); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: wifi.cx; centerY: wifi.cy; radiusX: 9.9; radiusY: 9.9; startAngle: -135; sweepAngle: 90 }
                }
                // Wi‑Fi apagado: tachado
                ShapePath {
                    strokeColor: root.wifiOn ? "transparent" : Kirigami.Theme.textColor
                    strokeWidth: 1.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: 3; startY: 1.5
                    PathLine { x: 15; y: 13.5 }
                }
            }
        }

        BarButton {
            id: sonidoBtn
            visible: root.showSonido
            abierto: root.abierto === "sonido"
            onClicked: root.menu("sonido", sonidoBtn)
            WheelHandler {
                property real acumulado: 0
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (ev) => {
                    acumulado += ev.angleDelta.y
                    while (Math.abs(acumulado) >= 120) {
                        root.cambiarVolumen(acumulado > 0 ? 0.05 : -0.05)
                        acumulado -= acumulado > 0 ? 120 : -120
                    }
                }
            }
            Shape {
                id: altavoz
                anchors.centerIn: parent
                width: 18; height: 14
                preferredRendererType: Shape.CurveRenderer
                readonly property color c: Kirigami.Theme.textColor
                // cuerpo y cono
                ShapePath {
                    strokeColor: "transparent"; fillColor: altavoz.c
                    startX: 0.5; startY: 4.6
                    PathLine { x: 3.4; y: 4.6 }
                    PathLine { x: 7.2; y: 1.2 }
                    PathLine { x: 7.2; y: 12.8 }
                    PathLine { x: 3.4; y: 9.4 }
                    PathLine { x: 0.5; y: 9.4 }
                    PathLine { x: 0.5; y: 4.6 }
                }
                ShapePath {
                    strokeColor: root.ondas >= 1 ? altavoz.c : "transparent"; strokeWidth: 1.7; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 7.6; centerY: 7; radiusX: 3.4; radiusY: 3.4; startAngle: -45; sweepAngle: 90 }
                }
                ShapePath {
                    strokeColor: root.ondas >= 2 ? altavoz.c : "transparent"; strokeWidth: 1.7; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 7.6; centerY: 7; radiusX: 6.3; radiusY: 6.3; startAngle: -45; sweepAngle: 90 }
                }
                ShapePath {
                    strokeColor: root.ondas >= 3 ? altavoz.c : "transparent"; strokeWidth: 1.7; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 7.6; centerY: 7; radiusX: 9.2; radiusY: 9.2; startAngle: -45; sweepAngle: 90 }
                }
                // silenciado: tachado sobre el altavoz
                ShapePath {
                    strokeColor: root.mudo ? altavoz.c : "transparent"; strokeWidth: 1.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: 1; startY: 1
                    PathLine { x: 13; y: 13 }
                }
            }
        }
    }
    fullRepresentation: Item {}

    // hueco de 30 px con el resalte en píldora de 26×20 al pulsar y con su menú abierto (Tahoe), igual que el
    // icono del Centro de Control
    component BarButton: MouseArea {
        id: bb
        property bool abierto: false
        Layout.preferredWidth: 30
        Layout.fillHeight: true
        Timer { id: pressedLook; interval: 180 }
        onPressed: pressedLook.restart()
        Rectangle {
            id: fondo
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: 26; height: 20; radius: 10
            color: bb.pressed || pressedLook.running ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.28) : bb.abierto ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2) : "transparent"
        }
        default property alias contenido: fondo.data
    }
}
