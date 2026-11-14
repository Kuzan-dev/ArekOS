import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Reloj de la barra de menús como en macOS Tahoe: «Sáb 14 nov. 4:42 p. m.» en una línea, en seminegrita, y al
// pulsarlo el calendario de vitrum-shell (vista "calendario" del Centro de Control: tarjeta de cristal suelta, mes
// en rojo, hoy en un círculo rojo). Sustituye al reloj de KDE, que con la
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
    // como en macOS: «Sáb 14 nov. 4:42 p. m.» (el día abreviado con mayúscula y sin punto, el mes con punto y
    // «a. m.»/«p. m.» en minúsculas con espacio)
    function textoFecha(d, f) {
        const corto = Qt.locale().dayName(d.getDay(), Locale.ShortFormat).replace(/\./g, "")
        const dia = corto.charAt(0).toUpperCase() + corto.slice(1)
        const mes = Qt.locale().monthName(d.getMonth(), Locale.ShortFormat).replace(/\./g, "") + "."
        return Qt.locale().toString(d, f.replace(/dddd|ddd|MMMM|MMM/g, t => t === "ddd" ? "'" + dia + "'" : t === "MMM" ? "'" + mes + "'" : t))
    }
    function textoHora(d) {
        const seg = cfg.showSeconds === 2
        if (cfg.use24hFormat !== 0) return Qt.formatTime(d, seg ? "HH:mm:ss" : "HH:mm")
        // Qt.formatTime da la hora de 24 h con «h» si el formato no lleva AP: se pasa a 12 h a mano
        const h = d.getHours() % 12 || 12
        const mm = String(d.getMinutes()).padStart(2, "0"), ss = String(d.getSeconds()).padStart(2, "0")
        return h + ":" + mm + (seg ? ":" + ss : "") + (d.getHours() < 12 ? " a. m." : " p. m.")
    }

    // calendario abierto: el reloj se resalta con una píldora, como en macOS Tahoe. Se marca al pulsar y, mientras
    // siga abierto, se pregunta a vitrum-shell (org.vitrum.Shell.Abierto) hasta que se cierre
    property bool abierto: false
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
            // la respuesta puede llegar antes de que vitrum-shell procese el clic: se ignora el primer instante
            if (source.indexOf("org.vitrum.Shell.Abierto") >= 0 && Date.now() - root.pulsado > 500) {
                root.abierto = (data.stdout || "").trim() === "calendario"
                if (!root.abierto) vigila.stop()
            }
            disconnectSource(source)
        }
    }
    function run(cmd) { sh.connectSource(cmd + " #" + Date.now()) }
    // las apps se abren en su propio grupo de procesos (scope de systemd): si cuelgan de plasmashell, Plasma las
    // cierra al reiniciarse (y con ellas lo que estuvieran haciendo, como aplicar una opción de la barra)
    function abrir(cmd) { run("setsid -f systemd-run --user --scope --collect --quiet " + cmd) }
    function calendario(item) {
        abierto = !abierto
        pulsado = Date.now()
        vigila.restart()
        const p = item.mapToGlobal(0, 0)
        run("dbus-send --session --type=method_call --dest=org.vitrum.Shell /Shell org.vitrum.Shell.ControlCenterMenu string:calendario int32:" + Math.round(p.x))
    }

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
        onClicked: root.calendario(compacto)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width; height: 20; radius: 10
            color: compacto.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.28)
                 : root.abierto ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2) : "transparent"
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
    // sin vista completa Plasma no muestra la compacta en la barra (el calendario/las notificaciones se abren aparte)
    fullRepresentation: Item {}

    component Etiqueta: Text {
        color: Kirigami.Theme.textColor
        font.family: root.cfg.fontFamily || "Inter"
        font.pointSize: root.cfg.fontSize || 10
        font.weight: root.cfg.boldText ? Font.Bold : (root.cfg.fontWeight || Font.Normal)
        renderType: Text.NativeRendering
    }
}
