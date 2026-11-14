import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects as GE
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

// Centro de Control de Vitrum al estilo de macOS Tahoe: panel flotante de 340 px a 5 px de la barra de menús y del
// borde derecho, esquinas de 30 px y módulos de cristal (píldoras, botones redondos, deslizadores finos) a 12 px del
// borde. Cada detalle (Wi‑Fi, Bluetooth, Sonido, Concentración) es un menú de 298 px con esquinas de 18 px, del
// tamaño de su contenido.
// Es una superficie transparente de pantalla completa: un clic fuera del panel lo cierra.
Window {
    id: cc
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "vitrum-centro-control#r" + panel.radius   // el radio lo usa el desenfoque de Vitrum (esquinas suavizadas)
    LayerShell.Window.scope: "control-center"
    // KWin la abre en la pantalla activa (la del puntero) al mostrarla, como macOS
    LayerShell.Window.wantsToBeOnActiveScreen: true
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    readonly property int barHeight: 32
    readonly property bool dark: Theme.dark
    readonly property color fg: dark ? "#FFFFFF" : "#1D1D1F"
    readonly property color fg2: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
    readonly property color off: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color accent: Theme.accent
    readonly property color sep: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
    // cristal de los módulos de Tahoe: relleno claro y filo blanco sobre el material del panel
    readonly property color glass: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color glassHover: dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.60)
    readonly property color glassEdge: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.75)
    readonly property color circleOff: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.08)
    readonly property string bin: Sys.home() + "/.local/bin/"

    // ── Estado ─────────────────────────────────────────────────────────────
    property var st: ({})
    property string view: ""                 // "" | "wifi" | "bt" | "sonido" | "concentracion"
    property var redes: []
    property var dispositivos: []
    property var salidas: []
    property string pidiendoClave: ""
    readonly property bool dnd: st.dnd !== undefined && st.dnd !== "" && new Date(st.dnd) > new Date()
    // menú suelto de un icono de la barra (Wi‑Fi, Sonido): solo esa vista, bajo el icono, como en macOS
    property bool menuMode: false
    property real menuX: 0

    function toggle() { visible ? close2() : open2() }
    function open2() {
        view = ""; pidiendoClave = ""; menuMode = false
        Theme.refresh()
        refresh()
        showFullScreen()
        Qt.callLater(updateRegions)
    }
    function close2() { hide(); view = ""; menuMode = false }
    // x llega en coordenadas globales (borde izquierdo del icono); la superficie ocupa solo su pantalla
    function menu(v, x) {
        if (visible && menuMode && view === v) { close2(); return }
        menuX = x - (screen ? screen.virtualX : 0)
        menuMode = true
        Theme.refresh()
        open(v)
        if (!visible) showFullScreen()
        Qt.callLater(updateRegions)
    }
    function open(v) { view = v; pidiendoClave = ""; redes = []; dispositivos = []; refresh() }

    function refresh() {
        Sys.runAsync("cc-estado", bin + "vitrum-cc-estado")
        if (view === "wifi") Sys.runAsync("cc-wifi", bin + "vitrum-cc-detalle", ["wifi"])
        if (view === "bt") Sys.runAsync("cc-bt", bin + "vitrum-cc-detalle", ["bt"])
        if (view === "sonido") Sys.runAsync("cc-sonido", "pactl", ["-f", "json", "list", "sinks"])
    }
    function sinkName(sk) {
        const p = sk.properties || {}
        const d = sk.description && sk.description !== "(null)" ? sk.description : ""
        return p["node.nick"] || d || p["device.description"] || p["device.product.name"] || sk.name
    }
    function act(cmd) { Sys.runAsync("cc-act", "bash", ["-c", cmd]) }
    function ajustes(page) { Sys.detached(bin + "vitrum-ajustes", [page]); close2() }
    Timer { interval: 3000; repeat: true; running: cc.visible; onTriggered: cc.refresh() }
    Connections {
        target: Sys
        function onFinished(tag, code, out) {
            if (tag === "cc-estado") {
                const s = {}
                for (const line of out.split("\n")) { const i = line.indexOf("="); if (i > 0) s[line.slice(0, i)] = line.slice(i + 1) }
                cc.st = s
            } else if (tag === "cc-wifi") cc.redes = out.split("\n").filter(l => l.indexOf("|") > 0).map(l => l.split("|"))
            else if (tag === "cc-bt") cc.dispositivos = out.split("\n").filter(l => l.indexOf("|") > 0).map(l => l.split("|"))
            else if (tag === "cc-sonido") { try { cc.salidas = JSON.parse(out) } catch (e) { cc.salidas = [] } }
            else if (tag === "cc-act") { Theme.refresh(); cc.refresh() }
        }
    }

    Mpris.Mpris2Model { id: mpris }
    // el que esté sonando; al pausarlo se queda (para poder reanudarlo) y, si no ha sonado ninguno, el actual de
    // KDE. currentPlayer solo no basta: puede quedarse en otro reproductor detenido (p. ej. una pestaña de Brave)
    // mientras suena Glassy Music
    Instantiator {
        id: reproductores
        model: mpris
        delegate: QtObject {
            readonly property var container: model.container
            readonly property bool multiplexer: model.isMultiplexer
            readonly property int estado: model.playbackStatus
        }
    }
    function reproductorAbierto(c) {
        for (let i = 0; i < reproductores.count; i++) { const r = reproductores.objectAt(i); if (r && r.container === c) return true }
        return false
    }
    readonly property var sonando: {
        for (let i = 0; i < reproductores.count; i++) {
            const r = reproductores.objectAt(i)
            if (r && !r.multiplexer && r.container && r.estado === Mpris.PlaybackStatus.Playing) return r.container
        }
        return null
    }
    property var ultimo: null
    onSonandoChanged: if (sonando) ultimo = sonando
    readonly property var player: sonando || (ultimo && reproductorAbierto(ultimo) ? ultimo : mpris.currentPlayer)

    // ── Superficie ─────────────────────────────────────────────────────────
    function updateRegions() {
        if (!visible) return
        // todo el ratón llega a la superficie (para cerrar al hacer clic fuera); el desenfoque, solo al panel
        Sys.setInputRegion(cc, 0, 0, width, height)
        Sys.setBlur(cc, panel.x, panel.y, panel.width, panel.height, panel.radius, Material.contrast, Material.intensity(panel.radius), Material.saturation)
    }
    onWidthChanged: Qt.callLater(updateRegions)
    MouseArea { anchors.fill: parent; onClicked: cc.close2() }
    Item { focus: cc.visible; Keys.onEscapePressed: cc.view !== "" && !cc.menuMode ? cc.view = "" : cc.close2() }

    MacPanel {
        id: panel
        radius: cc.view === "" ? 30 : 18
        width: cc.view === "" ? 340 : 298
        onRadiusChanged: cc.updateRegions()
        onWidthChanged: cc.updateRegions()
        // como menú, alineado con el icono que lo abre (sin salirse de la pantalla); si no, a la derecha
        x: cc.menuMode ? Math.max(6, Math.min(cc.width - 5 - 1 - width, cc.menuX - 6)) : cc.width - 5 - 1 - width
        y: cc.barHeight + 5 + 1
        height: cc.view === "" ? main.fullH : detail.fullH
        onHeightChanged: cc.updateRegions()
        onXChanged: cc.updateRegions()
        MouseArea { anchors.fill: parent }   // los clics dentro no cierran

        // Vista principal como en macOS Tahoe: dos columnas de 153 px; Wi‑Fi, Bluetooth, AirDrop, Modo oscuro y
        // Concentración en píldoras de 64 px, Música en un bloque de dos filas, botones redondos y deslizadores finos
        Column {
            id: main
            visible: cc.view === ""
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10
            readonly property real fullH: childrenRect.height + 24
            readonly property real col: (width - spacing) / 2
            Row {
                spacing: 10
                Column {
                    spacing: 10
                    Pill {
                        width: main.col
                        icon: cc.st.wifi_dev ? "network-wireless-symbolic" : "network-wired-symbolic"
                        title: cc.st.wifi_dev ? "Wi‑Fi" : "Red"
                        subtitle: cc.st.wifi_dev ? (cc.st.wifi_on === "enabled" ? (cc.st.wifi_dev.split(":")[1] || "Activado") : "Desactivado")
                                                 : (cc.st.ethernet ? "Ethernet" : "Sin conexión")
                        on: cc.st.wifi_dev ? cc.st.wifi_on === "enabled" : !!cc.st.ethernet
                        onToggle: cc.st.wifi_dev ? cc.act("nmcli radio wifi " + (on ? "off" : "on")) : cc.ajustes("red")
                        onOpen: cc.st.wifi_dev ? cc.open("wifi") : cc.ajustes("red")
                    }
                    Pill {
                        width: main.col
                        icon: "network-bluetooth-symbolic"
                        title: "Bluetooth"
                        subtitle: cc.st.bt === "1" ? (cc.st.bt_on === "yes" ? "Activado" : "Desactivado") : "No disponible"
                        on: cc.st.bt_on === "yes"
                        enabledToggle: cc.st.bt === "1"
                        onToggle: cc.act("timeout 3 bluetoothctl power " + (on ? "off" : "on"))
                        onOpen: cc.open("bt")
                    }
                }
                // Música: carátula arriba, título y artista, y los tres controles abajo
                Glass {
                    id: musica
                    width: main.col; height: 138
                    radius: 30
                    readonly property bool hay: !!cc.player
                    readonly property bool playing: hay && cc.player.playbackStatus === Mpris.PlaybackStatus.Playing
                    // clic en la carátula o el título: trae al frente la app que suena
                    MouseArea {
                        x: 0; y: 0; width: parent.width; height: 96
                        enabled: musica.hay && cc.player.canRaise
                        onClicked: { cc.player.Raise(); cc.close2() }
                    }
                    Rectangle {
                        x: 16; y: 14
                        width: 40; height: 40; radius: 8
                        color: cc.player && cc.player.artUrl ? "transparent" : cc.off
                        // esquinas redondeadas con máscara (clip recorta por el rectángulo, no por el radio)
                        Image { id: caratula; anchors.fill: parent; visible: false; source: cc.player ? cc.player.artUrl : ""; fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true; sourceSize.width: 120 }
                        Rectangle { id: caratulaMask; anchors.fill: parent; radius: 8; visible: false; antialiasing: true }
                        GE.OpacityMask { anchors.fill: parent; source: caratula; maskSource: caratulaMask; visible: caratula.status === Image.Ready }
                        Rectangle {
                            anchors.centerIn: parent; width: 24; height: 24; radius: 6; color: "#FA2D48"
                            visible: !cc.player || !cc.player.artUrl
                            T { anchors.centerIn: parent; text: "♫"; color: "white"; font.pixelSize: 14 }
                        }
                    }
                    Column {
                        x: 16; y: 62
                        width: parent.width - 30
                        T { width: parent.width; text: cc.player && cc.player.track ? cc.player.track : "Sin reproducción"; font.weight: Font.DemiBold }
                        T { width: parent.width; visible: !!(cc.player && cc.player.artist); text: cc.player ? cc.player.artist : ""; color: cc.fg2; font.pixelSize: 11 }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 38
                        spacing: 10
                        Transport { kind: "prev"; active: !!(cc.player && cc.player.canGoPrevious); onClicked: cc.player.Previous() }
                        Transport { kind: musica.playing ? "pause" : "play"; big: true; active: musica.hay; onClicked: cc.player.PlayPause() }
                        Transport { kind: "next"; active: !!(cc.player && cc.player.canGoNext); onClicked: cc.player.Next() }
                    }
                }
            }
            Row {
                spacing: 10
                Pill {
                    width: main.col
                    icon: "kdeconnect-tray-symbolic"
                    fallbackIcon: "smartphone-symbolic"
                    title: "AirDrop"
                    subtitle: "KDE Connect"
                    on: true
                    onToggle: { Sys.detached("kdeconnect-app"); cc.close2() }
                    onOpen: { Sys.detached("kdeconnect-app"); cc.close2() }
                }
                // botones redondos: luz nocturna y duplicar pantalla
                Row {
                    spacing: main.col - 2 * 64
                    RoundButton {
                        icon: "night-light-symbolic"; fallbackIcon: "weather-clear-night-symbolic"
                        on: cc.st.night === "true"
                        onColor: "#FF9F0A"
                        // KWin solo recarga la luz nocturna con el aviso de --notify (org.kde.KWin.reconfigure no la aplica)
                        onClicked: cc.act("kwriteconfig6 --notify --file kwinrc --group NightColor --key Active " + (on ? "false" : "true"))
                    }
                    RoundButton {
                        icon: "preferences-desktop-display-randr-symbolic"
                        onClicked: { cc.act("dbus-send --session --type=method_call --dest=org.kde.kscreen.osdService /org/kde/kscreen/osdService org.kde.kscreen.osdService.showActionSelector"); cc.close2() }
                    }
                }
            }
            Row {
                spacing: 10
                // encendido, la píldora entera se vuelve blanca, como «Dark Mode On» en macOS
                Pill {
                    width: main.col
                    icon: "contrast-symbolic"
                    title: "Modo oscuro"
                    subtitle: on ? "Activado" : "Desactivado"
                    on: cc.st.scheme === "VitrumDark"
                    white: on
                    // toda la píldora cambia el modo, como en macOS (no tiene menú de detalle)
                    onToggle: cc.act(cc.bin + "vitrum-modo " + (on ? "claro" : "oscuro") + " --aplicar")
                    onOpen: toggle()
                }
                Pill {
                    width: main.col
                    icon: "weather-clear-night-symbolic"
                    title: "Concentración"
                    subtitle: cc.dnd ? "No molestar" : ""
                    on: cc.dnd
                    onToggle: cc.open("concentracion")
                    onOpen: cc.open("concentracion")
                }
            }
            // Pantalla: una barra por monitor, sol pequeño y sol grande a los lados
            Glass {
                width: main.width
                height: pantalla.implicitHeight + 26
                Column {
                    id: pantalla
                    x: 16; y: 12
                    width: parent.width - 32
                    spacing: 6
                    T { text: "Pantalla"; font.weight: Font.DemiBold }
                    Repeater {
                        model: cc.st.disp ? cc.st.disp.split(";").map(d => d.split("|")) : []
                        Column {
                            required property var modelData
                            width: pantalla.width
                            spacing: 2
                            T { visible: cc.st.disp.indexOf(";") > 0; width: parent.width; text: parent.modelData[1]; color: cc.fg2; font.pixelSize: 11 }
                            SliderRow {
                                width: parent.width
                                lowIcon: "display-brightness-low-symbolic"
                                highIcon: "display-brightness-high-symbolic"
                                value: Number(parent.modelData[2] || 0)
                                onMoved: (v) => cc.act("qdbus-qt6 org.kde.ScreenBrightness /org/kde/ScreenBrightness/" + parent.modelData[0]
                                                       + " org.kde.ScreenBrightness.Display.SetBrightness " + Math.round(v * Number(parent.modelData[3] || 100) / 100) + " 0")
                            }
                        }
                    }
                }
            }
            // Sonido: barra entre altavoz bajo y alto, y botón de salida (abre la lista, como AirPlay en macOS)
            Glass {
                width: main.width; height: 76
                HoverHandler { id: sonidoHover }
                T { x: 16; y: 12; text: "Sonido"; font.weight: Font.DemiBold }
                // salida actual y flecha › al pasar el ratón
                T {
                    anchors.right: parent.right; anchors.rightMargin: 16; y: 12
                    width: parent.width - 100; horizontalAlignment: Text.AlignRight
                    visible: sonidoHover.hovered
                    text: (cc.st.sink && cc.st.sink !== "(null)" ? cc.st.sink + "  " : "") + "›"
                    color: cc.fg2; font.pixelSize: 11
                }
                MouseArea { x: 0; y: 0; width: parent.width; height: 32; onClicked: cc.open("sonido") }
                SliderRow {
                    x: 16; y: 40
                    width: parent.width - 32 - 30 - 8
                    lowIcon: cc.st.mute === "yes" ? "audio-volume-muted-symbolic" : "audio-volume-low-symbolic"
                    highIcon: "audio-volume-high-symbolic"
                    value: cc.st.mute === "yes" ? 0 : Number(cc.st.vol || 0)
                    onMoved: (v) => cc.act("pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(v) + "%")
                }
                Rectangle {
                    x: parent.width - 16 - width; y: 38
                    width: 28; height: 28; radius: 14
                    color: cc.circleOff
                    Kirigami.Icon { anchors.centerIn: parent; width: 15; height: 15; source: "audio-speakers-symbolic"; isMask: true; color: cc.fg }
                    MouseArea { anchors.fill: parent; onClicked: cc.open("sonido") }
                }
            }
        }

        // Vistas de detalle (como los menús de macOS): título, contenido, separador y acceso a Ajustes
        Column {
            id: detail
            visible: cc.view !== ""
            x: 0; y: 6
            width: parent.width
            readonly property real fullH: childrenRect.height + 12
            // cabecera
            Item {
                width: parent.width; height: 34
                T { x: 14; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.Bold
                    text: ({ wifi: "Wi‑Fi", bt: "Bluetooth", sonido: "Sonido", concentracion: "Concentración" })[cc.view] || "" }
                Switch2 {
                    visible: cc.view === "wifi" || cc.view === "bt"
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    on: cc.view === "wifi" ? cc.st.wifi_on === "enabled" : cc.st.bt_on === "yes"
                    onToggled: cc.view === "wifi" ? cc.act("nmcli radio wifi " + (on ? "off" : "on")) : cc.act("timeout 3 bluetoothctl power " + (on ? "off" : "on"))
                }
            }
            // Sonido: barra de volumen bajo el título
            Item {
                visible: cc.view === "sonido"
                width: parent.width; height: visible ? 30 : 0
                SliderRow {
                    x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                    lowIcon: cc.st.mute === "yes" ? "audio-volume-muted-symbolic" : "audio-volume-low-symbolic"
                    highIcon: "audio-volume-high-symbolic"
                    value: cc.st.mute === "yes" ? 0 : Number(cc.st.vol || 0)
                    onMoved: (v) => cc.act("pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(v) + "%")
                }
            }
            Sep { visible: cc.view !== "bt" || cc.dispositivos.length > 0 }
            Header { visible: cc.view === "wifi" && cc.redes.some(r => r[0] === "1"); text: "Red preferida" }
            Header { visible: cc.view === "bt" && cc.dispositivos.length > 0; text: "Dispositivos" }
            Header { visible: cc.view === "sonido"; text: "Salida" }
            Txt2 {
                visible: cc.view === "wifi" && cc.redes.length === 0
                text: cc.st.wifi_on === "enabled" ? "Buscando redes…" : "Wi‑Fi desactivado"
            }
            Repeater {
                model: cc.view === "wifi" ? cc.redes.filter(r => r[0] === "1").concat(cc.redes.filter(r => r[0] !== "1")) : []
                Column {
                    required property var modelData
                    required property int index
                    width: detail.width
                    // macOS: la red conectada bajo «Red preferida» y el resto bajo «Otras redes»
                    Header { visible: modelData[0] !== "1" && index === cc.redes.filter(r => r[0] === "1").length; text: "Otras redes" }
                    ListRow {
                        on: modelData[0] === "1"
                        icon: "network-wireless-symbolic"
                        title: modelData[1]
                        lock: modelData[3] && modelData[3] !== "--"
                        onClicked: {
                            if (on) return
                            const id = modelData[1].replace(/'/g, "")
                            cc.pidiendoClave = ""
                            cc.act("nmcli -t -f NAME con show | grep -qxF '" + id + "' && nmcli con up id '" + id + "' || "
                                   + (lock ? "exit 3" : "nmcli dev wifi connect '" + id + "'"))
                            if (lock) cc.pidiendoClave = modelData[1]
                        }
                    }
                    Rectangle {
                        visible: cc.pidiendoClave === modelData[1] && modelData[0] !== "1"
                        x: 48; width: parent.width - 62; height: visible ? 24 : 0; radius: 6
                        color: cc.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.8)
                        border.width: 1; border.color: cc.accent
                        TextInput {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password; color: cc.fg; font.pixelSize: 12
                            focus: parent.visible
                            onAccepted: { cc.act("nmcli dev wifi connect '" + modelData[1].replace(/'/g, "") + "' password '" + text.replace(/'/g, "") + "'"); cc.pidiendoClave = ""; text = "" }
                            Text { visible: !parent.text; text: "Contraseña"; color: cc.fg2; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
            Repeater {
                model: cc.view === "bt" ? cc.dispositivos : []
                ListRow {
                    required property var modelData
                    on: modelData[2] === "1"
                    icon: modelData[3].indexOf("audio") >= 0 ? "audio-headphones-symbolic"
                        : modelData[3].indexOf("keyboard") >= 0 ? "input-keyboard-symbolic"
                        : modelData[3].indexOf("mouse") >= 0 ? "input-mouse-symbolic"
                        : modelData[3].indexOf("phone") >= 0 ? "smartphone-symbolic" : "network-bluetooth-symbolic"
                    title: modelData[1]
                    trailing: on ? "Conectado" : ""
                    onClicked: cc.act("timeout 10 bluetoothctl " + (on ? "disconnect " : "connect ") + modelData[0])
                }
            }
            Repeater {
                model: cc.view === "sonido" ? cc.salidas : []
                ListRow {
                    required property var modelData
                    on: modelData.name === cc.st.sink_name
                    icon: /hdmi|displayport/i.test(modelData.name) ? "video-display-symbolic"
                        : /headphone|headset|usb/i.test(modelData.description + modelData.name) ? "audio-headphones-symbolic" : "audio-speakers-symbolic"
                    // PipeWire deja la descripción en "(null)": el nombre útil está en node.nick
                    title: cc.sinkName(modelData)
                    onClicked: cc.act("pactl set-default-sink '" + modelData.name + "'")
                }
            }
            // Concentración: No molestar y sus duraciones
            ListRow {
                visible: cc.view === "concentracion"
                on: cc.dnd
                glyph: "☾"
                title: "No molestar"
                onClicked: cc.act(cc.dnd ? "kwriteconfig6 --notify --file plasmanotifyrc --group DoNotDisturb --key Until --delete"
                                          : "kwriteconfig6 --notify --file plasmanotifyrc --group DoNotDisturb --key Until 2099-01-01T00:00:00")
            }
            ListRow {
                visible: cc.view === "concentracion"; plain: true; indent: 48
                title: "Durante 1 hora"
                onClicked: cc.act("kwriteconfig6 --notify --file plasmanotifyrc --group DoNotDisturb --key Until " + new Date(Date.now() + 3600000).toISOString().slice(0, 19))
            }
            ListRow {
                visible: cc.view === "concentracion"; plain: true; indent: 48
                title: "Hasta esta noche"
                onClicked: { const d = new Date(); d.setHours(23, 59, 0, 0); cc.act("kwriteconfig6 --notify --file plasmanotifyrc --group DoNotDisturb --key Until " + new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 19)) }
            }
            Sep {}
            ListRow {
                plain: true
                title: ({ wifi: "Ajustes de Wi‑Fi…", bt: "Ajustes de Bluetooth…", sonido: "Ajustes de Sonido…", concentracion: "Ajustes de Concentración…" })[cc.view] || ""
                onClicked: cc.ajustes(({ wifi: "wifi", bt: "bluetooth", sonido: "sonido", concentracion: "concentracion" })[cc.view])
            }
        }
    }

    // ── Piezas ─────────────────────────────────────────────────────────────
    component T: Text {
        color: cc.fg
        font.family: Theme.font
        font.pixelSize: 13
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }
    component Txt2: T { x: 14; height: 28; verticalAlignment: Text.AlignVCenter; color: cc.fg2 }
    component Header: T { x: 14; height: 24; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; font.weight: Font.DemiBold; color: cc.fg2 }
    component Sep: Item {
        width: parent ? parent.width : 0; height: 11
        Rectangle { x: 14; width: parent.width - 28; height: 1; anchors.verticalCenter: parent.verticalCenter; color: cc.sep }
    }
    component Circle: Rectangle {
        property string icon: ""
        property string fallbackIcon: ""
        property string glyph: ""
        property bool on: false
        property bool dim: false
        width: 26; height: 26; radius: 13
        color: on ? cc.accent : cc.off
        opacity: dim ? 0.5 : 1
        Kirigami.Icon { anchors.centerIn: parent; width: 14; height: 14; visible: parent.icon !== ""; source: parent.icon; fallback: parent.fallbackIcon; isMask: true; color: parent.on ? "white" : cc.fg }
        Text { anchors.centerIn: parent; visible: parent.glyph !== ""; text: parent.glyph; color: parent.on ? "white" : cc.fg; font.pixelSize: 14 }
    }
    component Switch2: Rectangle {
        id: sw
        property bool on: false
        signal toggled()
        width: 38; height: 22; radius: 11
        color: on ? cc.accent : cc.off
        Rectangle { width: 20; height: 20; radius: 10; y: 1; x: sw.on ? sw.width - width - 1 : 1; color: "white"; Behavior on x { NumberAnimation { duration: 120 } } }
        MouseArea { anchors.fill: parent; onClicked: sw.toggled() }
    }
    component ListRow: Item {
        id: lr
        property string icon: ""
        property string glyph: ""
        property string title: ""
        property string trailing: ""
        property bool on: false
        property bool lock: false
        property bool plain: false
        property int indent: 14
        signal clicked()
        width: parent ? parent.width : 0
        height: visible ? (plain ? 26 : 34) : 0
        Rectangle {
            anchors.fill: parent; anchors.leftMargin: 5; anchors.rightMargin: 5
            radius: 5
            color: lrHover.hovered ? (cc.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
        }
        Circle {
            visible: !lr.plain
            x: lr.indent; anchors.verticalCenter: parent.verticalCenter
            icon: lr.icon; glyph: lr.glyph; on: lr.on
        }
        T {
            x: lr.plain ? lr.indent : lr.indent + 34
            width: parent.width - x - 40
            anchors.verticalCenter: parent.verticalCenter
            text: lr.title
        }
        T {
            visible: lr.trailing !== "" && !lr.lock
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            text: lr.trailing
            color: cc.fg2; font.pixelSize: 11
        }
        Kirigami.Icon {
            visible: lr.lock
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12; source: "object-locked-symbolic"; isMask: true; color: cc.fg2
        }
        HoverHandler { id: lrHover }
        MouseArea { anchors.fill: parent; onClicked: lr.clicked() }
    }
    // controles de música dibujados (los caracteres ▶ y ❚❚ cambian de tamaño y grosor según la fuente):
    // reproducir y pausa grandes, anterior y siguiente con dos triángulos, como en macOS
    component Transport: Item {
        id: tr
        property string kind: "play"        // play | pause | prev | next
        property bool big: false
        property bool active: true
        signal clicked()
        width: 30; height: 26
        opacity: active ? 1 : 0.35
        scale: trMouse.pressed ? 0.85 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Shape {
            visible: tr.kind === "play"
            anchors.centerIn: parent; anchors.horizontalCenterOffset: 1.5
            width: 16; height: 18
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: cc.fg; strokeColor: cc.fg; strokeWidth: 1.5; joinStyle: ShapePath.RoundJoin
                startX: 1; startY: 1
                PathLine { x: 15; y: 9 }
                PathLine { x: 1; y: 17 }
                PathLine { x: 1; y: 1 }
            }
        }
        Row {
            visible: tr.kind === "pause"
            anchors.centerIn: parent; spacing: 4.5
            Repeater { model: 2; Rectangle { width: 5; height: 17; radius: 1.5; color: cc.fg } }
        }
        Shape {
            visible: tr.kind === "prev" || tr.kind === "next"
            anchors.centerIn: parent
            width: 20; height: 12
            // anterior: el mismo dibujo reflejado
            transform: Scale { origin.x: 10; xScale: tr.kind === "prev" ? -1 : 1 }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: cc.fg; strokeColor: cc.fg; strokeWidth: 1.2; joinStyle: ShapePath.RoundJoin
                startX: 1; startY: 1
                PathLine { x: 10; y: 6 }
                PathLine { x: 1; y: 11 }
                PathLine { x: 1; y: 1 }
                PathMove { x: 10; y: 1 }
                PathLine { x: 19; y: 6 }
                PathLine { x: 10; y: 11 }
                PathLine { x: 10; y: 1 }
            }
        }
        MouseArea { id: trMouse; anchors.fill: parent; anchors.margins: -4; enabled: tr.active; onClicked: tr.clicked() }
    }
    // módulo de cristal de Tahoe (Pantalla, Sonido, Música)
    component Glass: Rectangle {
        radius: 26
        antialiasing: true
        color: cc.glass
        border.width: 1
        border.color: cc.glassEdge
    }
    // píldora de 64 px: círculo de 40 px (activa/desactiva) y texto (abre el detalle). Encendido: círculo blanco con
    // el icono en color; white vuelve blanca la píldora entera (Modo oscuro)
    component Pill: Rectangle {
        id: pl
        property string icon: ""
        property string fallbackIcon: ""
        property string title: ""
        property string subtitle: ""
        property bool on: false
        property bool white: false
        property bool enabledToggle: true
        signal toggle()
        signal open()
        height: 64; radius: 32
        antialiasing: true
        color: white ? "#FFFFFF" : plHover.hovered ? cc.glassHover : cc.glass
        border.width: white ? 0 : 1
        border.color: cc.glassEdge
        HoverHandler { id: plHover }
        Rectangle {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: pl.white ? Qt.rgba(0, 0, 0, 0.06) : pl.on ? "#FFFFFF" : cc.circleOff
            opacity: pl.enabledToggle ? 1 : 0.5
            scale: plCircle.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Kirigami.Icon {
                anchors.centerIn: parent; width: 20; height: 20
                source: pl.icon; fallback: pl.fallbackIcon; isMask: true
                color: pl.white ? "#1D1D1F" : pl.on ? cc.accent : cc.fg
            }
            MouseArea { id: plCircle; anchors.fill: parent; enabled: pl.enabledToggle; onClicked: pl.toggle() }
        }
        Column {
            x: 58; anchors.verticalCenter: parent.verticalCenter
            width: pl.width - 58 - 12
            spacing: -1
            // los nombres en español son más largos que en macOS («Concentración»): la letra se reduce hasta 11 px antes de cortar
            T { width: parent.width; text: pl.title; font.weight: Font.DemiBold; color: pl.white ? "#1D1D1F" : cc.fg; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 11 }
            T { width: parent.width; visible: pl.subtitle !== ""; text: pl.subtitle; font.pixelSize: 11; color: pl.white ? Qt.rgba(0, 0, 0, 0.5) : cc.fg2 }
        }
        MouseArea { x: 54; width: pl.width - 54; height: pl.height; onClicked: pl.open() }
    }
    // botón redondo de 64 px; encendido, blanco con el icono en color
    component RoundButton: Rectangle {
        id: rb
        property string icon: ""
        property string fallbackIcon: ""
        property bool on: false
        property color onColor: cc.accent
        signal clicked()
        width: 64; height: 64; radius: 32
        antialiasing: true
        color: on ? "#FFFFFF" : rbHover.hovered ? cc.glassHover : cc.glass
        border.width: on ? 0 : 1
        border.color: cc.glassEdge
        scale: rbMouse.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        HoverHandler { id: rbHover }
        Kirigami.Icon {
            anchors.centerIn: parent; width: 24; height: 24
            source: rb.icon; fallback: rb.fallbackIcon; isMask: true
            color: rb.on ? rb.onColor : cc.fg
        }
        MouseArea { id: rbMouse; anchors.fill: parent; onClicked: rb.clicked() }
    }
    // deslizador fino de Tahoe con un icono a cada lado; la barra engorda al pasar el ratón
    component SliderRow: Item {
        id: sr
        property string lowIcon: ""
        property string highIcon: ""
        property alias value: thin.value
        signal moved(real v)
        height: 24
        Kirigami.Icon { id: lo; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; source: sr.lowIcon; isMask: true; color: cc.fg }
        ThinSlider {
            id: thin
            x: 22; anchors.verticalCenter: parent.verticalCenter
            width: sr.width - 22 - 28
            onMoved: (v) => sr.moved(v)
        }
        Kirigami.Icon { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 19; height: 19; source: sr.highIcon; isMask: true; color: cc.fg }
    }
    component ThinSlider: Item {
        id: ts
        property real value: 50
        signal moved(real v)
        height: 24
        property real shown: value
        onValueChanged: if (!tsDrag.pressed) shown = value
        readonly property bool grande: tsHover.hovered || tsDrag.pressed
        HoverHandler { id: tsHover }
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: ts.grande ? 9 : 5; radius: height / 2
            Behavior on height { NumberAnimation { duration: 120 } }
            color: cc.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)
            Rectangle {
                width: Math.max(parent.height, parent.width * ts.shown / 100); height: parent.height; radius: height / 2
                color: cc.dark ? "#FFFFFF" : Qt.rgba(0, 0, 0, 0.75)
            }
        }
        MouseArea {
            id: tsDrag
            anchors.fill: parent
            function upd(mx) { ts.shown = Math.max(0, Math.min(100, mx / ts.width * 100)) }
            onPressed: (e) => upd(e.x)
            onPositionChanged: (e) => { if (pressed) { upd(e.x); if (!tsLive.running) tsLive.start() } }
            onReleased: { tsLive.stop(); ts.moved(ts.shown) }
            Timer { id: tsLive; interval: 120; onTriggered: ts.moved(ts.shown) }
        }
    }
}
