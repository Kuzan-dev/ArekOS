import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects as GE
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

// Centro de Control de Vitrum al estilo de macOS Tahoe: módulos de cristal sueltos (píldoras, botones redondos,
// deslizadores finos), sin panel de fondo, a 6 px de la barra de menús y del borde derecho. Cada detalle (Wi‑Fi,
// Bluetooth, Sonido, Pantalla, Concentración) es un menú con esquinas de 18 px, del tamaño de su contenido.
// Es una superficie transparente de pantalla completa: un clic fuera del panel lo cierra.
Window {
    id: cc
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "vitrum-centro-control#r" + (cc.view === "" ? 30 : panel.radius)   // el radio lo usa el desenfoque de Vitrum (esquinas suavizadas)
    // tipo «mensaje en pantalla» para KWin: con un ámbito que no conoce («control-center») la trataba como ventana
    // normal y su efecto Escala animaba la superficie entera (el degradado oscuro se veía subir como un rectángulo)
    LayerShell.Window.scope: "on-screen-display"
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
    property string view: ""                 // "" | "wifi" | "bt" | "sonido" | "pantalla" | "concentracion" | "calendario"
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
        aparecer()
        Qt.callLater(updateRegions)
    }
    function close2() { hide(); view = ""; menuMode = false; entrada.stop(); aparicion = 1 }

    // Aparición de la vista principal y del calendario: los módulos y el oscurecimiento se funden y crecen un poco
    // desde la esquina en 0,3 s. Arranca con el primer fotograma ya dibujado (si no, la animación corre antes de
    // que la ventana llegue a la pantalla y no se ve) y el desenfoque se pone al terminar: puesto antes, KWin lo
    // muestra de golpe y parece una ventana detrás de los módulos
    property real aparicion: 1
    property bool arrancar: false
    function aparecer() { entrada.stop(); aparicion = 0; arrancar = true; respaldo.restart() }
    function arrancarEntrada() { if (!arrancar) return; arrancar = false; entrada.restart() }
    onFrameSwapped: arrancarEntrada()
    Timer { id: respaldo; interval: 150; onTriggered: cc.arrancarEntrada() }   // por si no llega frameSwapped
    NumberAnimation {
        id: entrada
        target: cc; property: "aparicion"
        from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic
        onFinished: cc.updateRegions()
    }
    // x llega en coordenadas globales (borde izquierdo del icono); la superficie ocupa solo su pantalla
    function menu(v, x) {
        if (visible && menuMode && view === v) { close2(); return }
        menuX = x - (screen ? screen.virtualX : 0)
        menuMode = true
        Theme.refresh()
        open(v)
        if (v === "calendario") calendario.mes = calendario.esteMes()
        if (!visible) { showFullScreen(); if (v === "calendario") aparecer() }
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
    // piezas de cristal de la vista principal (las que tienen la propiedad cristal), en coordenadas de la ventana
    function piezas(item, out) {
        for (const c of item.children) {
            if (!c.visible) continue
            if (c.cristal) { const p = c.mapToItem(null, 0, 0); out.push([p.x, p.y, c.width, c.height, c.radio]) }
            else piezas(c, out)
        }
        return out
    }
    function updateRegions() {
        if (!visible) return
        // todo el ratón llega a la superficie (para cerrar al hacer clic fuera); el desenfoque, solo al cristal:
        // en la vista principal y en el calendario cada módulo por separado, como en Tahoe; en los menús, el panel
        Sys.setInputRegion(cc, 0, 0, width, height)
        if ((cc.view === "" || cc.view === "calendario") && cc.aparicion < 1) Sys.clearBlur(cc)
        else if (cc.view === "" || cc.view === "calendario")
            Sys.setBlurRects(cc, piezas(cc.view === "" ? main : calendario, []), Material.contrast, Material.intensity(30), Material.saturation)
        else Sys.setBlur(cc, panel.x, panel.y, panel.width, panel.height, panel.radius, Material.contrast, Material.intensity(panel.radius), Material.saturation)
    }
    onWidthChanged: Qt.callLater(updateRegions)
    onViewChanged: Qt.callLater(updateRegions)
    MouseArea { anchors.fill: parent; onClicked: cc.close2() }
    // Tahoe oscurece ligeramente el escritorio alrededor del Centro de Control: un degradado centrado en los módulos,
    // de ~25 % junto a ellos que se apaga poco a poco (sin meseta, para que no parezca el borde de una ventana).
    // Los menús sueltos de la barra no lo llevan (el calendario del reloj, sí). Aparece con los módulos (aparicion)
    GE.RadialGradient {
        id: velo
        anchors.fill: parent
        visible: !cc.menuMode || cc.view === "calendario"
        readonly property Item foco: cc.view === "calendario" ? calendario : main
        horizontalOffset: foco.x + foco.width / 2 - width / 2
        verticalOffset: foco.y + foco.height * 0.4 - height / 2
        horizontalRadius: 620
        verticalRadius: 760
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.26) }
            GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0, 0.20) }
            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.11) }
            GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.04) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: cc.aparicion
    }
    Item { focus: cc.visible; Keys.onEscapePressed: cc.view !== "" && !cc.menuMode ? cc.view = "" : cc.close2() }

    // Vista principal como en macOS Tahoe: sin panel de fondo, cada módulo es un cristal suelto sobre el escritorio.
    // Dos columnas de 142 px a 12 px; Wi‑Fi, Bluetooth, AirDrop y Concentración en píldoras de 64 px, Música en un
    // bloque de dos filas, botones redondos de 64 px, Pantalla y Sonido en bloques y «Editar controles» debajo
    // los clics entre los módulos no cierran
    MouseArea { visible: main.visible; x: main.x; y: main.y; width: main.width; height: main.height }
    Column {
        id: main
        visible: cc.view === ""
        opacity: cc.aparicion
        scale: 0.94 + 0.06 * cc.aparicion
        transformOrigin: Item.TopRight
        width: 296
        x: cc.width - 6 - width
        y: cc.barHeight + 6
        spacing: 12
        readonly property real col: (width - spacing) / 2
        onHeightChanged: Qt.callLater(cc.updateRegions)
        onXChanged: Qt.callLater(cc.updateRegions)

        Row {
            spacing: 12
            Column {
                spacing: 12
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
                width: main.col; height: 2 * 64 + 12
                radio: 30
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
            spacing: 12
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
                    onClicked: cc.nocturna(on)
                }
                RoundButton {
                    icon: "preferences-desktop-display-randr-symbolic"
                    onClicked: cc.duplicar()
                }
            }
        }
        Row {
            spacing: 12
            // Modo oscuro y captura de pantalla en botones redondos, como en Tahoe; encendido, el círculo es blanco
            Row {
                spacing: main.col - 2 * 64
                RoundButton {
                    icon: "contrast-symbolic"
                    on: cc.st.scheme === "VitrumDark"
                    onColor: "#1D1D1F"
                    onClicked: cc.modoOscuro(on)
                }
                RoundButton {
                    icon: "camera-photo-symbolic"; fallbackIcon: "spectacle"
                    onClicked: { cc.close2(); Sys.detached("bash", ["-c", "sleep 0.3; spectacle -r"]) }
                }
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
        // Pantalla: una barra por monitor, sol pequeño y sol grande a los lados; el título abre el menú de Pantalla
        Glass {
            width: main.width
            height: pantalla.implicitHeight + 26
            HoverHandler { id: pantallaHover }
            MouseArea { x: 0; y: 0; width: parent.width; height: 32; onClicked: cc.open("pantalla") }
            T {
                anchors.right: parent.right; anchors.rightMargin: 16; y: 12
                visible: pantallaHover.hovered
                text: "›"; color: cc.fg2; font.pixelSize: 11
            }
            Column {
                id: pantalla
                x: 16; y: 12
                width: parent.width - 32
                spacing: 6
                T { text: "Pantalla"; font.weight: Font.DemiBold }
                Brillo { width: parent.width }
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
        // «Editar controles»: los que también se muestran en la barra de menús (Ajustes → Barra de menús)
        Item {
            width: main.width; height: 26
            Glass {
                readonly property bool hover: editarHover.hovered
                anchors.centerIn: parent
                width: editar.implicitWidth + 28; height: 26
                radio: 13
                HoverHandler { id: editarHover }
                T { id: editar; anchors.centerIn: parent; text: "Editar controles"; font.pixelSize: 12; color: parent.hover ? cc.fg : cc.fg2 }
                MouseArea { anchors.fill: parent; onClicked: cc.ajustes("barra") }
            }
        }
    }
    // Calendario del reloj (vista "calendario", la abre el plasmoide org.vitrum.calendario por ControlCenterMenu):
    // como el Centro de Control, una tarjeta de cristal suelta bajo el reloj (mes en rojo, hoy en un círculo rojo,
    // ‹ › para cambiar de mes) y debajo «Ajustes de fecha y hora…»
    MouseArea { visible: calendario.visible; x: calendario.x; y: calendario.y; width: calendario.width; height: calendario.height }
    Column {
        id: calendario
        visible: cc.view === "calendario"
        opacity: cc.aparicion
        scale: 0.94 + 0.06 * cc.aparicion
        transformOrigin: Item.TopRight
        width: 296
        x: cc.width - 6 - width
        y: cc.barHeight + 6
        spacing: 12
        onHeightChanged: Qt.callLater(cc.updateRegions)
        onVisibleChanged: if (visible) hoy = new Date()
        property date hoy: new Date()
        Timer { interval: 30000; repeat: true; running: calendario.visible; onTriggered: calendario.hoy = new Date() }
        function esteMes() { return new Date(hoy.getFullYear(), hoy.getMonth(), 1) }
        property date mes: esteMes()
        readonly property int primerDia: Qt.locale().firstDayOfWeek          // 1 = lunes … 7 = domingo
        readonly property int desfase: (mes.getDay() - primerDia % 7 + 7) % 7
        readonly property int diasMes: new Date(mes.getFullYear(), mes.getMonth() + 1, 0).getDate()
        readonly property bool mesActual: mes.getFullYear() === hoy.getFullYear() && mes.getMonth() === hoy.getMonth()
        function mover(n) { mes = new Date(mes.getFullYear(), mes.getMonth() + n, 1) }

        Glass {
            width: calendario.width
            height: calCol.implicitHeight + 30
            radio: 26
            Column {
                id: calCol
                x: 18; y: 14
                width: parent.width - 36
                spacing: 8
                T {
                    width: parent.width
                    text: { const t = Qt.locale().toString(calendario.hoy, "dddd, d 'de' MMMM"); return t.charAt(0).toUpperCase() + t.slice(1) }
                    font.weight: Font.Bold
                }
                Item {
                    width: parent.width; height: 20
                    T {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 60
                        text: Qt.locale().standaloneMonthName(calendario.mes.getMonth()).toUpperCase()
                              + (calendario.mes.getFullYear() !== calendario.hoy.getFullYear() ? " " + calendario.mes.getFullYear() : "")
                        color: "#FF3B30"; font.pixelSize: 12; font.weight: Font.Bold
                        MouseArea { anchors.fill: parent; onClicked: calendario.mes = calendario.esteMes() }
                    }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: [-1, 1]
                            Rectangle {
                                required property int modelData
                                width: 24; height: 24; radius: 12
                                color: flechaHover.hovered ? cc.circleOff : "transparent"
                                HoverHandler { id: flechaHover }
                                T { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: parent.modelData < 0 ? "‹" : "›"; font.pixelSize: 18; color: cc.fg2 }
                                MouseArea { anchors.fill: parent; onClicked: calendario.mover(parent.modelData) }
                            }
                        }
                    }
                }
                Grid {
                    columns: 7
                    readonly property real celda: calCol.width / 7
                    Repeater {
                        model: 7
                        T {
                            width: parent.celda; height: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.locale().dayName((calendario.primerDia + index) % 7, Locale.NarrowFormat).toUpperCase()
                            font.pixelSize: 10; font.weight: Font.DemiBold; color: cc.fg2
                        }
                    }
                    Repeater {
                        model: calendario.desfase + calendario.diasMes
                        Item {
                            width: parent.celda; height: 30
                            readonly property int dia: index - calendario.desfase + 1
                            readonly property bool esHoy: calendario.mesActual && dia === calendario.hoy.getDate()
                            Rectangle {
                                anchors.centerIn: parent
                                visible: parent.esHoy
                                width: 26; height: 26; radius: 13
                                color: "#FF3B30"
                            }
                            T {
                                anchors.centerIn: parent
                                visible: parent.dia > 0
                                text: parent.dia
                                font.weight: parent.esHoy ? Font.Bold : Font.Normal
                                color: parent.esHoy ? "white" : cc.fg
                            }
                        }
                    }
                }
            }
        }
        // como «Editar controles» del Centro de Control
        Item {
            width: calendario.width; height: 26
            Glass {
                readonly property bool hover: fechaHover.hovered
                anchors.centerIn: parent
                width: fechaTxt.implicitWidth + 28; height: 26
                radio: 13
                HoverHandler { id: fechaHover }
                T { id: fechaTxt; anchors.centerIn: parent; text: "Ajustes de fecha y hora…"; font.pixelSize: 12; color: parent.hover ? cc.fg : cc.fg2 }
                MouseArea { anchors.fill: parent; onClicked: cc.ajustes("fecha") }
            }
        }
    }
    function nocturna(on) {
        // KWin solo recarga la luz nocturna con el aviso de --notify (org.kde.KWin.reconfigure no la aplica)
        act("kwriteconfig6 --notify --file kwinrc --group NightColor --key Active " + (on ? "false" : "true"))
    }
    function modoOscuro(on) { act(bin + "vitrum-modo " + (on ? "claro" : "oscuro") + " --aplicar") }
    function duplicar() {
        act("dbus-send --session --type=method_call --dest=org.kde.kscreen.osdService /org/kde/kscreen/osdService org.kde.kscreen.osdService.showActionSelector")
        close2()
    }

    // Menús (Wi‑Fi, Bluetooth, Sonido, Pantalla, Concentración): un panel de 298 px (340 el de Pantalla) con esquinas
    // de 18 px, del tamaño de su contenido
    MacPanel {
        id: panel
        visible: cc.view !== "" && cc.view !== "calendario"
        radius: 18
        width: cc.view === "pantalla" ? 340 : 298
        onWidthChanged: cc.updateRegions()
        // como menú, alineado con el icono que lo abre (sin salirse de la pantalla); si no, a la derecha
        x: cc.menuMode ? Math.max(6, Math.min(cc.width - 5 - 1 - width, cc.menuX - 6)) : cc.width - 5 - 1 - width
        y: cc.barHeight + 5 + 1
        height: detail.fullH
        onHeightChanged: cc.updateRegions()
        onXChanged: cc.updateRegions()
        MouseArea { anchors.fill: parent }   // los clics dentro no cierran

        // Vistas de detalle (como los menús de macOS): título, contenido, separador y acceso a Ajustes
        Column {
            id: detail
            visible: panel.visible
            x: 0; y: 6
            width: parent.width
            readonly property real fullH: childrenRect.height + 12
            // cabecera
            Item {
                width: parent.width; height: 34
                T { x: 14; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.Bold
                    text: ({ wifi: "Wi‑Fi", bt: "Bluetooth", sonido: "Sonido", pantalla: "Pantalla", concentracion: "Concentración" })[cc.view] || "" }
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
            // Pantalla, como en Tahoe: el brillo con perilla y debajo Modo oscuro, Luz nocturna y Duplicar, con su estado
            Brillo {
                visible: cc.view === "pantalla"
                x: 14; width: parent.width - 28
                perilla: true
            }
            Row {
                visible: cc.view === "pantalla"
                x: 14; topPadding: 12; bottomPadding: 6
                readonly property real ancho: (detail.width - 28) / 3
                Opcion {
                    width: parent.ancho
                    icon: "contrast-symbolic"; title: "Modo oscuro"
                    on: cc.st.scheme === "VitrumDark"; onColor: "#1D1D1F"
                    onClicked: cc.modoOscuro(on)
                }
                Opcion {
                    width: parent.ancho
                    icon: "night-light-symbolic"; fallbackIcon: "weather-clear-night-symbolic"; title: "Luz nocturna"
                    on: cc.st.night === "true"; onColor: "#FF9F0A"
                    onClicked: cc.nocturna(on)
                }
                Opcion {
                    width: parent.ancho
                    icon: "preferences-desktop-display-randr-symbolic"; title: "Duplicar"; status: "Pantallas"
                    onClicked: cc.duplicar()
                }
            }
            Sep { visible: cc.view !== "pantalla" && (cc.view !== "bt" || cc.dispositivos.length > 0) }
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
                title: ({ wifi: "Ajustes de Wi‑Fi…", bt: "Ajustes de Bluetooth…", sonido: "Ajustes de Sonido…", pantalla: "Ajustes de Pantallas…", concentracion: "Ajustes de Concentración…" })[cc.view] || ""
                onClicked: cc.ajustes(({ wifi: "wifi", bt: "bluetooth", sonido: "sonido", pantalla: "pantallas", concentracion: "concentracion" })[cc.view])
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
    // capa del cristal sobre el tinte del material (los dos son translúcidos): un solo color, para pintarlo con la
    // esquina continua de MaterialEdge
    function capa(base, top) {
        const a = top.a + base.a * (1 - top.a)
        if (a <= 0) return "transparent"
        const c = (t, b) => (t * top.a + b * base.a * (1 - top.a)) / a
        return Qt.rgba(c(top.r, base.r), c(top.g, base.g), c(top.b, base.b), a)
    }
    // fondo de un módulo: material, contorno y filo blanco. cristal y radio los usa updateRegions para el desenfoque
    component Fondo: MaterialEdge {
        property bool hover: false
        property bool white: false
        anchors.fill: parent
        fill: white ? "#FFFFFF" : cc.capa(Material.tintColor, hover ? cc.glassHover : cc.glass)
        outline: Material.outline
        highlight: white ? "transparent" : cc.glassEdge
    }
    // módulo de cristal de Tahoe (Pantalla, Sonido, Música)
    component Glass: Item {
        readonly property bool cristal: true
        property real radio: 26
        Fondo { radius: parent.radio; hover: !!parent.hover }
    }
    // píldora de 64 px: círculo de 40 px (activa/desactiva) y texto (abre el detalle). Encendido: círculo blanco con
    // el icono en color
    component Pill: Item {
        id: pl
        readonly property bool cristal: true
        readonly property real radio: 32
        property string icon: ""
        property string fallbackIcon: ""
        property string title: ""
        property string subtitle: ""
        property bool on: false
        property bool enabledToggle: true
        signal toggle()
        signal open()
        height: 64
        Fondo { radius: pl.radio; hover: plHover.hovered }
        HoverHandler { id: plHover }
        Rectangle {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: pl.on ? "#FFFFFF" : cc.circleOff
            opacity: pl.enabledToggle ? 1 : 0.5
            scale: plCircle.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Kirigami.Icon {
                anchors.centerIn: parent; width: 20; height: 20
                source: pl.icon; fallback: pl.fallbackIcon; isMask: true
                color: pl.on ? cc.accent : cc.fg
            }
            MouseArea { id: plCircle; anchors.fill: parent; enabled: pl.enabledToggle; onClicked: pl.toggle() }
        }
        Column {
            x: 58; anchors.verticalCenter: parent.verticalCenter
            width: pl.width - 58 - 8
            spacing: -1
            // los nombres en español son más largos que en macOS («Concentración»): la letra se reduce hasta 10 px antes de cortar
            T { width: parent.width; text: pl.title; font.weight: Font.DemiBold; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 10 }
            // como en Tahoe, un nombre de red largo pasa a una segunda línea
            T { width: parent.width; visible: pl.subtitle !== ""; text: pl.subtitle; font.pixelSize: 11; color: cc.fg2
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere; maximumLineCount: 2; lineHeight: 0.95 }
        }
        MouseArea { x: 54; width: pl.width - 54; height: pl.height; onClicked: pl.open() }
    }
    // botón redondo de 64 px; encendido, blanco con el icono en color
    component RoundButton: Item {
        id: rb
        readonly property bool cristal: true
        readonly property real radio: width / 2
        property string icon: ""
        property string fallbackIcon: ""
        property bool on: false
        property color onColor: cc.accent
        signal clicked()
        width: 64; height: 64
        scale: rbMouse.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Fondo { radius: rb.radio; hover: rbHover.hovered; white: rb.on }
        HoverHandler { id: rbHover }
        Kirigami.Icon {
            anchors.centerIn: parent; width: 24; height: 24
            source: rb.icon; fallback: rb.fallbackIcon; isMask: true
            color: rb.on ? rb.onColor : cc.fg
        }
        MouseArea { id: rbMouse; anchors.fill: parent; onClicked: rb.clicked() }
    }
    // opción del menú de Pantalla: círculo de 44 px y debajo el nombre y su estado
    component Opcion: Column {
        id: op
        property string icon: ""
        property string fallbackIcon: ""
        property string title: ""
        property string status: on ? "Activado" : "Desactivado"
        property bool on: false
        property color onColor: cc.accent
        signal clicked()
        spacing: 2
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44; height: 44; radius: 22
            color: op.on ? "#FFFFFF" : cc.circleOff
            scale: opMouse.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Kirigami.Icon {
                anchors.centerIn: parent; width: 20; height: 20
                source: op.icon; fallback: op.fallbackIcon; isMask: true
                color: op.on ? op.onColor : cc.fg
            }
            MouseArea { id: opMouse; anchors.fill: parent; onClicked: op.clicked() }
        }
        Item { width: 1; height: 4 }
        T { width: op.width; horizontalAlignment: Text.AlignHCenter; text: op.title; font.pixelSize: 12; font.weight: Font.DemiBold }
        T { width: op.width; horizontalAlignment: Text.AlignHCenter; text: op.status; font.pixelSize: 11; color: cc.fg2 }
    }
    // brillo: una barra por monitor (con su nombre si hay varios), sol pequeño y sol grande a los lados
    component Brillo: Column {
        id: br
        property bool perilla: false
        spacing: 2
        Repeater {
            model: cc.st.disp ? cc.st.disp.split(";").map(d => d.split("|")) : []
            Column {
                required property var modelData
                width: br.width
                spacing: 2
                T { visible: cc.st.disp.indexOf(";") > 0; width: parent.width; text: parent.modelData[1]; color: cc.fg2; font.pixelSize: 11 }
                SliderRow {
                    width: parent.width
                    perilla: br.perilla
                    lowIcon: "display-brightness-low-symbolic"
                    highIcon: "display-brightness-high-symbolic"
                    value: Number(parent.modelData[2] || 0)
                    onMoved: (v) => cc.act("qdbus-qt6 org.kde.ScreenBrightness /org/kde/ScreenBrightness/" + parent.modelData[0]
                                           + " org.kde.ScreenBrightness.Display.SetBrightness " + Math.round(v * Number(parent.modelData[3] || 100) / 100) + " 0")
                }
            }
        }
    }
    // deslizador fino de Tahoe con un icono a cada lado; la barra engorda al pasar el ratón
    component SliderRow: Item {
        id: sr
        property string lowIcon: ""
        property string highIcon: ""
        property alias value: thin.value
        property alias perilla: thin.perilla
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
        // perilla: como el del menú de Pantalla de Tahoe, barra fija de 6 px con una perilla blanca
        property bool perilla: false
        signal moved(real v)
        height: 24
        property real shown: value
        onValueChanged: if (!tsDrag.pressed) shown = value
        readonly property bool grande: tsHover.hovered || tsDrag.pressed
        HoverHandler { id: tsHover }
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: ts.perilla ? 6 : ts.grande ? 9 : 5; radius: height / 2
            Behavior on height { NumberAnimation { duration: 120 } }
            color: cc.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)
            Rectangle {
                width: Math.max(parent.height, parent.width * ts.shown / 100); height: parent.height; radius: height / 2
                color: cc.dark ? "#FFFFFF" : Qt.rgba(0, 0, 0, 0.75)
            }
        }
        Rectangle {
            visible: ts.perilla
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 18; radius: 9
            x: (ts.width - width) * ts.shown / 100
            color: "#FFFFFF"
            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
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
