import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

// Widget de escritorio mediano de macOS Tahoe (344×164, como los de la Mac: 164 pt de alto y 16 de separación) con
// el uso de la CPU, la GPU, la RAM y la VRAM en anillos, como el widget de Baterías, y debajo la temperatura o la
// memoria usada. Los datos salen de ksystemstats, salvo la temperatura de la CPU: ksystemstats la da a 0 con los
// Ryzen que solo tienen Tctl/Tccd, así que se lee de k10temp (temp1 = Tctl), buscando su hwmon por nombre.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property bool oscuro: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    readonly property color texto: oscuro ? "#ffffff" : "#1d1d1f"
    readonly property color secundario: oscuro ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)

    property real cpuTemp: 0

    Sensors.Sensor { id: cpuUso; sensorId: "cpu/all/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuUso; sensorId: "gpu/gpu0/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuTemp; sensorId: "gpu/gpu0/temperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ramPct; sensorId: "memory/physical/usedPercent"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ramUsada; sensorId: "memory/physical/used"; updateRateLimit: 2000 }
    Sensors.Sensor { id: vramUsada; sensorId: "gpu/gpu0/usedVram"; updateRateLimit: 2000 }
    Sensors.Sensor { id: vramTotal; sensorId: "gpu/gpu0/totalVram"; updateRateLimit: 10000 }

    P5Support.DataSource {
        engine: "executable"
        interval: 2000
        connectedSources: ["for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name)\" = k10temp ] && cat $h/temp1_input && break; done"]
        onNewData: (source, data) => {
            const v = parseInt(data["stdout"]);
            if (!isNaN(v)) root.cpuTemp = v / 1000;
        }
    }

    function gb(bytes) {
        return (bytes / 1073741824).toLocaleString(Qt.locale(), "f", 1) + " GB";
    }
    // verde, amarillo y rojo como los anillos de macOS
    function colorUso(p) {
        return p < 60 ? "#30d158" : p < 85 ? "#ffd60a" : "#ff453a";
    }
    function colorTemp(t) {
        return t < 75 ? root.secundario : t < 85 ? "#ff9f0a" : "#ff453a";
    }

    fullRepresentation: Item {
        Layout.minimumWidth: 344
        Layout.minimumHeight: 164
        Layout.preferredWidth: 344
        Layout.preferredHeight: 164

        // tarjeta: gris oscuro casi opaco con un borde claro de 1 px, medido en el widget de Calendario de la Mac
        Rectangle {
            anchors.fill: parent
            radius: 22
            color: root.oscuro ? Qt.rgba(0.19, 0.19, 0.195, 0.9) : Qt.rgba(0.97, 0.97, 0.975, 0.9)
            border.width: 1
            border.color: root.oscuro ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.7)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 0

            Anillo {
                etiqueta: "CPU"
                valor: cpuUso.value || 0
                detalle: root.cpuTemp > 0 ? Math.round(root.cpuTemp) + " °C" : "—"
                colorDetalle: root.colorTemp(root.cpuTemp)
            }
            Anillo {
                etiqueta: "GPU"
                valor: gpuUso.value || 0
                detalle: gpuTemp.value > 0 ? Math.round(gpuTemp.value) + " °C" : "—"
                colorDetalle: root.colorTemp(gpuTemp.value || 0)
            }
            Anillo {
                etiqueta: "RAM"
                valor: ramPct.value || 0
                detalle: root.gb(ramUsada.value || 0)
            }
            Anillo {
                etiqueta: "VRAM"
                valor: vramTotal.value > 0 ? 100 * vramUsada.value / vramTotal.value : 0
                detalle: root.gb(vramUsada.value || 0)
            }
        }
    }

    component Anillo: ColumnLayout {
        property string etiqueta
        property real valor
        property string detalle
        property color colorDetalle: root.secundario

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 2

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
            id: aro
            implicitWidth: 58
            implicitHeight: 58

            property real mostrado: Math.max(0, Math.min(100, valor))
            Behavior on mostrado { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 6
                    strokeColor: root.oscuro ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.1)
                    fillColor: "transparent"
                    PathAngleArc { centerX: 29; centerY: 29; radiusX: 26; radiusY: 26; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeWidth: 6
                    strokeColor: root.colorUso(aro.mostrado)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 29; centerY: 29; radiusX: 26; radiusY: 26
                        startAngle: -90
                        sweepAngle: 3.6 * Math.max(aro.mostrado, 0.5)
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: etiqueta
                color: root.texto
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Math.round(valor) + " %"
            color: root.texto
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: detalle
            color: colorDetalle
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }
}
