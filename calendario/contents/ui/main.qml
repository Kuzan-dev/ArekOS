import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Reloj de la barra de menús como en macOS Tahoe: «sáb 14 nov. 11:21» en una línea, en seminegrita, y al
// pulsarlo el widget de calendario (mes en rojo, hoy en un círculo rojo). Sustituye al reloj de KDE, que con la
// fecha al lado de la hora la monta sobre ella. Usa sus mismas claves (grupo Appearance), así que conserva su
// configuración; se cambia en clic derecho → Configurar… o en Ajustes → Barra de menús → Opciones del reloj.
PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property var cfg: Plasmoid.configuration
    readonly property string bin: "$HOME/.local/bin/"

    // ── Fecha y hora ───────────────────────────────────────────────────────
    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    readonly property string hora: textoHora(now)
    readonly property string fecha: cfg.showDate ? textoFecha(now, cfg.customDateFormat || "ddd d MMM") : ""
    // como en macOS: «sáb 14 nov. 11:58 a.m.» (el día abreviado sin punto, el mes con punto y a.m./p.m. en minúsculas)
    function textoFecha(d, f) {
        const dia = Qt.locale().dayName(d.getDay(), Locale.ShortFormat).replace(/\./g, "")
        const mes = Qt.locale().monthName(d.getMonth(), Locale.ShortFormat).replace(/\./g, "") + "."
        return Qt.locale().toString(d, f.replace(/dddd|ddd|MMMM|MMM/g, t => t === "ddd" ? "'" + dia + "'" : t === "MMM" ? "'" + mes + "'" : t))
    }
    function textoHora(d) {
        const seg = cfg.showSeconds === 2
        if (cfg.use24hFormat !== 0) return Qt.formatTime(d, seg ? "HH:mm:ss" : "HH:mm")
        return Qt.formatTime(d, seg ? "h:mm:ss" : "h:mm") + (d.getHours() < 12 ? " a.m." : " p.m.")
    }

    // ── Colores (sobre el fondo de los menús emergentes de Plasma) ───────────
    readonly property color fg: Kirigami.Theme.textColor
    readonly property bool dark: (fg.r + fg.g + fg.b) / 3 > 0.5
    readonly property color fg2: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property color glass: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.5)
    readonly property color glassEdge: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.8)
    readonly property color rojo: "#FF3B30"

    P5Support.DataSource { id: sh; engine: "executable"; onNewData: (s) => disconnectSource(s) }
    function run(cmd) { sh.connectSource(cmd + " #" + Date.now()) }
    // las apps se abren en su propio grupo de procesos (scope de systemd): si cuelgan de plasmashell, Plasma las
    // cierra al reiniciarse (y con ellas lo que estuvieran haciendo, como aplicar una opción de la barra)
    function abrir(cmd) { run("setsid -f systemd-run --user --scope --collect --quiet " + cmd) }

    // clic derecho (Plasma añade «Configurar Reloj…» con la página de configGeneral.qml)
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Ajustar fecha y hora…"
            icon.name: "preferences-system-time"
            onTriggered: root.abrir(root.bin + "vitrum-ajustes fecha")
        },
        PlasmaCore.Action {
            text: "Copiar fecha y hora"
            icon.name: "edit-copy"
            onTriggered: root.run("printf %s '" + Qt.locale().toString(new Date(), "dddd d 'de' MMMM 'de' yyyy, HH:mm").replace(/'/g, "") + "' | wl-copy")
        }
    ]

    // ── En la barra: fecha y hora en una línea, con la píldora de Tahoe mientras está abierto ──
    compactRepresentation: MouseArea {
        id: compacto
        Layout.preferredWidth: fila.implicitWidth + 14
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        onClicked: root.expanded = !root.expanded
        Rectangle {
            anchors.centerIn: parent
            width: parent.width; height: 20; radius: 10
            color: compacto.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.28)
                 : root.expanded ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2) : "transparent"
        }
        // fecha y hora separadas como en macOS (un poco más que un espacio)
        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 7
            Etiqueta { visible: root.fecha !== ""; text: root.fecha }
            Etiqueta { text: root.hora }
        }
    }
    component Etiqueta: Text {
        color: Kirigami.Theme.textColor
        font.family: root.cfg.fontFamily || "Inter"
        font.pointSize: root.cfg.fontSize || 10
        font.weight: root.cfg.boldText ? Font.Bold : (root.cfg.fontWeight || Font.Normal)
        renderType: Text.NativeRendering
    }

    // ── Calendario ───────────────────────────────────────────────────────────
    fullRepresentation: Item {
        Layout.preferredWidth: 300
        Layout.minimumWidth: 300
        Layout.maximumWidth: 300
        Layout.preferredHeight: col.implicitHeight + 24
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight
        ColumnLayout {
            id: col
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10
            T {
                Layout.leftMargin: 4
                text: Qt.locale().toString(root.now, "dddd, d 'de' MMMM 'de' yyyy")
                font.weight: Font.Bold
            }
            Calendario { Layout.fillWidth: true }
            T {
                Layout.leftMargin: 4
                text: "Ajustes de fecha y hora…"
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { root.abrir(root.bin + "vitrum-ajustes fecha"); root.expanded = false } }
            }
        }
    }

    component T: Text {
        color: root.fg
        font.pixelSize: 13
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }

    // widget de calendario de Tahoe: mes en rojo, iniciales de los días y hoy en un círculo rojo
    component Calendario: Rectangle {
        id: cal
        property date mes: new Date(root.now.getFullYear(), root.now.getMonth(), 1)
        readonly property int primerDia: Qt.locale().firstDayOfWeek          // 1 = lunes … 7 = domingo
        readonly property int desfase: (mes.getDay() - primerDia % 7 + 7) % 7
        readonly property int diasMes: new Date(mes.getFullYear(), mes.getMonth() + 1, 0).getDate()
        readonly property bool esteMes: mes.getFullYear() === root.now.getFullYear() && mes.getMonth() === root.now.getMonth()
        function mover(n) { mes = new Date(mes.getFullYear(), mes.getMonth() + n, 1) }
        implicitHeight: calCol.implicitHeight + 28
        radius: 20
        color: root.glass
        border.width: 1; border.color: root.glassEdge
        // vuelve al mes actual al abrir el calendario
        Connections { target: root; function onExpandedChanged() { if (root.expanded) cal.mes = new Date(root.now.getFullYear(), root.now.getMonth(), 1) } }

        ColumnLayout {
            id: calCol
            x: 16; y: 14
            width: cal.width - 32
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                T {
                    Layout.fillWidth: true
                    text: Qt.locale().standaloneMonthName(cal.mes.getMonth()).toUpperCase() + (cal.mes.getFullYear() !== root.now.getFullYear() ? " " + cal.mes.getFullYear() : "")
                    color: root.rojo; font.pixelSize: 12; font.weight: Font.Bold
                    MouseArea { anchors.fill: parent; onClicked: cal.mes = new Date(root.now.getFullYear(), root.now.getMonth(), 1) }
                }
                T { text: "‹"; font.pixelSize: 18; color: root.fg2; MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.mover(-1) } }
                Item { implicitWidth: 10 }
                T { text: "›"; font.pixelSize: 18; color: root.fg2; MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.mover(1) } }
            }
            Grid {
                Layout.fillWidth: true
                columns: 7
                readonly property real celda: calCol.width / 7
                Repeater {
                    model: 7
                    T {
                        width: parent.celda; height: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName((cal.primerDia + index) % 7, Locale.NarrowFormat).toUpperCase()
                        font.pixelSize: 10; font.weight: Font.DemiBold; color: root.fg2
                    }
                }
                Repeater {
                    model: cal.desfase + cal.diasMes
                    Item {
                        width: parent.celda; height: 26
                        readonly property int dia: index - cal.desfase + 1
                        readonly property bool hoy: cal.esteMes && dia === root.now.getDate()
                        Rectangle {
                            anchors.centerIn: parent
                            visible: parent.hoy
                            width: 24; height: 24; radius: 12
                            color: root.rojo
                        }
                        T {
                            anchors.centerIn: parent
                            visible: parent.dia > 0
                            text: parent.dia
                            font.pixelSize: 12
                            font.weight: parent.hoy ? Font.Bold : Font.Normal
                            color: parent.hoy ? "white" : root.fg
                        }
                    }
                }
            }
        }
    }
}
