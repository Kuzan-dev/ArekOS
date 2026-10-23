import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

// Centro de Control de Vitrum, con las medidas y el material del de macOS Monterey: panel flotante de 300 px
// (contorno incluido) a 5 px de la barra de menús y del borde derecho, esquinas de 15 px, módulos a 10 px del
// borde. Cada detalle (Wi‑Fi, Bluetooth, Sonido, Concentración) cambia el panel al tamaño de su contenido.
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
    readonly property string bin: Sys.home() + "/.local/bin/"

    // ── Estado ─────────────────────────────────────────────────────────────
    property var st: ({})
    property string view: ""                 // "" | "wifi" | "bt" | "sonido" | "concentracion"
    property var redes: []
    property var dispositivos: []
    property var salidas: []
    property string pidiendoClave: ""
    readonly property bool dnd: st.dnd !== undefined && st.dnd !== "" && new Date(st.dnd) > new Date()

    function toggle() { visible ? close2() : open2() }
    function open2() {
        view = ""; pidiendoClave = ""
        Theme.refresh()
        refresh()
        showFullScreen()
        Qt.callLater(updateRegions)
    }
    function close2() { hide(); view = "" }
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
            else if (tag === "cc-act") cc.refresh()
        }
    }

    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer

    // ── Superficie ─────────────────────────────────────────────────────────
    function updateRegions() {
        if (!visible) return
        // todo el ratón llega a la superficie (para cerrar al hacer clic fuera); el desenfoque, solo al panel
        Sys.setInputRegion(cc, 0, 0, width, height)
        Sys.setBlur(cc, panel.x, panel.y, panel.width, panel.height, panel.radius, Material.contrast, 1.0, Material.saturation)
    }
    onWidthChanged: Qt.callLater(updateRegions)
    MouseArea { anchors.fill: parent; onClicked: cc.close2() }
    Item { focus: cc.visible; Keys.onEscapePressed: cc.view !== "" ? cc.view = "" : cc.close2() }

    MacPanel {
        id: panel
        radius: 15
        width: 298
        x: cc.width - 5 - 1 - width
        y: cc.barHeight + 5 + 1
        height: cc.view === "" ? main.fullH : detail.fullH
        onHeightChanged: cc.updateRegions()
        onXChanged: cc.updateRegions()
        MouseArea { anchors.fill: parent }   // los clics dentro no cierran

        // Vista principal: dos columnas de 135 px, módulos de 61 px (el de red, 133)
        Column {
            id: main
            visible: cc.view === ""
            x: 9; y: 9
            width: parent.width - 18
            spacing: 10
            readonly property real fullH: childrenRect.height + 18
            Row {
                spacing: 10
                Module {
                    width: 135; height: 133
                    Column {
                        x: 10; y: 13
                        width: parent.width - 20
                        spacing: 14
                        Toggle {
                            width: parent.width
                            icon: cc.st.wifi_dev ? "network-wireless-symbolic" : "network-wired-symbolic"
                            title: cc.st.wifi_dev ? "Wi‑Fi" : "Red"
                            subtitle: cc.st.wifi_dev ? (cc.st.wifi_on === "enabled" ? (cc.st.wifi_dev.split(":")[1] || "Activado") : "Desactivado")
                                                     : (cc.st.ethernet ? "Ethernet" : "Sin conexión")
                            on: cc.st.wifi_dev ? cc.st.wifi_on === "enabled" : !!cc.st.ethernet
                            onToggle: cc.st.wifi_dev ? cc.act("nmcli radio wifi " + (on ? "off" : "on")) : cc.ajustes("red")
                            onOpen: cc.st.wifi_dev ? cc.open("wifi") : cc.ajustes("red")
                        }
                        Toggle {
                            width: parent.width
                            icon: "network-bluetooth-symbolic"
                            title: "Bluetooth"
                            subtitle: cc.st.bt === "1" ? (cc.st.bt_on === "yes" ? "Activado" : "Desactivado") : "No disponible"
                            on: cc.st.bt_on === "yes"
                            enabledToggle: cc.st.bt === "1"
                            onToggle: cc.act("timeout 3 bluetoothctl power " + (on ? "off" : "on"))
                            onOpen: cc.open("bt")
                        }
                        Toggle {
                            width: parent.width
                            icon: "kdeconnect-tray-symbolic"
                            fallbackIcon: "smartphone-symbolic"
                            title: "AirDrop"
                            subtitle: "KDE Connect"
                            onToggle: Sys.detached("kdeconnect-app")
                            onOpen: Sys.detached("kdeconnect-app")
                        }
                    }
                }
                Column {
                    spacing: 11
                    Module {
                        width: 135; height: 61
                        BigButton {
                            anchors.fill: parent
                            glyph: "☾"
                            title: "Concentra-\nción"
                            on: cc.dnd
                            onClicked: cc.open("concentracion")
                        }
                    }
                    Module {
                        width: 135; height: 61
                        BigButton {
                            anchors.fill: parent
                            plainIcon: "preferences-desktop-display-randr-symbolic"
                            title: "Duplicar\npantalla"
                            onClicked: { cc.act("dbus-send --session --type=method_call --dest=org.kde.kscreen.osdService /org/kde/kscreen/osdService org.kde.kscreen.osdService.showActionSelector"); cc.close2() }
                        }
                    }
                }
            }
            // Pantalla: una barra por monitor
            Module {
                width: 280
                height: pantalla.implicitHeight + 19
                Column {
                    id: pantalla
                    x: 10; y: 9
                    width: parent.width - 20
                    spacing: 6
                    T { text: "Pantalla"; font.weight: Font.DemiBold }
                    Repeater {
                        model: cc.st.disp ? cc.st.disp.split(";").map(d => d.split("|")) : []
                        Column {
                            required property var modelData
                            width: pantalla.width
                            spacing: 3
                            T { visible: cc.st.disp.indexOf(";") > 0; width: parent.width; text: parent.modelData[1]; color: cc.fg2; font.pixelSize: 11 }
                            CCSlider {
                                width: parent.width
                                glyph: "☀"
                                value: Number(parent.modelData[2] || 0)
                                onMoved: (v) => cc.act("qdbus-qt6 org.kde.ScreenBrightness /org/kde/ScreenBrightness/" + parent.modelData[0]
                                                       + " org.kde.ScreenBrightness.Display.SetBrightness " + Math.round(v * Number(parent.modelData[3] || 100) / 100) + " 0")
                            }
                        }
                    }
                }
            }
            // Sonido: barra y botón de salida (abre la lista de salidas, como AirPlay en macOS)
            Module {
                width: 280; height: 61
                HoverHandler { id: sonidoHover }
                T { x: 10; y: 9; text: "Sonido"; font.weight: Font.DemiBold }
                // salida actual y flecha › al pasar el ratón: abre la lista de salidas (altavoces, auriculares…)
                T {
                    anchors.right: parent.right; anchors.rightMargin: 10; y: 9
                    width: parent.width - 90; horizontalAlignment: Text.AlignRight
                    visible: sonidoHover.hovered
                    text: (cc.st.sink && cc.st.sink !== "(null)" ? cc.st.sink + "  " : "") + "›"
                    color: cc.fg2; font.pixelSize: 11
                }
                MouseArea { x: 0; y: 0; width: parent.width; height: 28; onClicked: cc.open("sonido") }
                CCSlider {
                    x: 10; y: 30
                    width: parent.width - 20 - 26 - 8
                    glyph: cc.st.mute === "yes" ? "🔇" : "🔈"
                    value: cc.st.mute === "yes" ? 0 : Number(cc.st.vol || 0)
                    onMoved: (v) => cc.act("pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(v) + "%")
                }
                Circle {
                    x: parent.width - 10 - width; y: 27
                    icon: "audio-speakers-symbolic"
                    MouseArea { anchors.fill: parent; onClicked: cc.open("sonido") }
                }
            }
            // Música
            Module {
                width: 280; height: 61
                Rectangle {
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 42; radius: 6; clip: true
                    color: cc.player && cc.player.artUrl ? "transparent" : cc.off
                    Image { anchors.fill: parent; source: cc.player ? cc.player.artUrl : ""; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                    Rectangle {
                        anchors.centerIn: parent; width: 20; height: 20; radius: 5; color: "#FA2D48"
                        visible: !cc.player || !cc.player.artUrl
                        T { anchors.centerIn: parent; text: "♫"; color: "white"; font.pixelSize: 13 }
                    }
                }
                Column {
                    x: 60; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 60 - 64
                    T { width: parent.width; text: cc.player && cc.player.track ? cc.player.track : "Música"; font.weight: Font.DemiBold }
                    T { width: parent.width; visible: !!(cc.player && cc.player.artist); text: cc.player ? cc.player.artist : ""; color: cc.fg2; font.pixelSize: 11 }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    T {
                        text: cc.player && cc.player.playbackStatus === Mpris.PlaybackStatus.Playing ? "❚❚" : "▶"
                        font.pixelSize: 16; color: cc.player ? cc.fg : cc.fg2
                        MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: !!cc.player; onClicked: cc.player.PlayPause() }
                    }
                    T {
                        text: "▶▶"; font.pixelSize: 12; color: cc.player && cc.player.canGoNext ? cc.fg : cc.fg2
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: !!(cc.player && cc.player.canGoNext); onClicked: cc.player.Next() }
                    }
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
                CCSlider {
                    x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                    glyph: "🔈"
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
    // módulo medido en macOS sobre el material del panel: una sola línea de 1 px (negro al 25 % en oscuro) y
    // relleno negro al 16 % (oscuro) o blanco al 35 % (claro); sin filo claro
    component Module: Rectangle {
        radius: 10
        antialiasing: true
        color: cc.dark ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.35)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, cc.dark ? 0.25 : 0.06)
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
    // fila de red: círculo (activa/desactiva) y texto (abre el detalle); al pasar el ratón aparece la flecha ›,
    // como en macOS
    component Toggle: Item {
        id: tg
        property string icon: ""
        property string fallbackIcon: ""
        property string title: ""
        property string subtitle: ""
        property bool on: false
        property bool enabledToggle: true
        signal toggle()
        signal open()
        height: 26
        Circle {
            icon: tg.icon; fallbackIcon: tg.fallbackIcon; on: tg.on; dim: !tg.enabledToggle
            MouseArea { anchors.fill: parent; enabled: tg.enabledToggle; onClicked: tg.toggle() }
        }
        Column {
            x: 34; anchors.verticalCenter: parent.verticalCenter
            width: tg.width - 34 - (tgHover.hovered ? 14 : 0)
            spacing: -1
            T { width: parent.width; text: tg.title; font.weight: Font.DemiBold }
            T { width: parent.width; text: tg.subtitle; color: cc.fg2; font.pixelSize: 11 }
        }
        T { visible: tgHover.hovered; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "›"; font.pixelSize: 18; color: cc.fg2 }
        HoverHandler { id: tgHover }
        MouseArea { x: 30; width: tg.width - 30; height: tg.height; onClicked: tg.open() }
    }
    // módulo de 61 px: círculo (o icono suelto) a 10 px y texto de dos líneas a 44 px
    component BigButton: Item {
        id: bb
        property string icon: ""
        property string plainIcon: ""
        property string glyph: ""
        property string title: ""
        property bool on: false
        signal clicked()
        Circle { visible: bb.plainIcon === ""; x: 10; anchors.verticalCenter: parent.verticalCenter; icon: bb.icon; glyph: bb.glyph; on: bb.on }
        Kirigami.Icon { visible: bb.plainIcon !== ""; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; source: bb.plainIcon; isMask: true; color: cc.fg }
        T {
            x: 44; width: parent.width - 44 - 8
            anchors.verticalCenter: parent.verticalCenter
            text: bb.title; font.weight: Font.DemiBold
            elide: Text.ElideNone; lineHeight: 0.95
        }
        MouseArea { anchors.fill: parent; onClicked: bb.clicked() }
    }
    // fila de los menús de detalle: círculo azul si está activa, texto, candado o dato a la derecha
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
    component CCSlider: Item {
        id: sl
        property real value: 50
        property string glyph: ""
        signal moved(real v)
        height: 20
        property real shown: value
        onValueChanged: if (!drag.pressed) shown = value
        Rectangle {
            anchors.fill: parent; radius: height / 2
            color: cc.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
            border.width: cc.dark ? 0 : 0.5; border.color: Qt.rgba(0, 0, 0, 0.08)
        }
        Rectangle { width: Math.max(height, sl.width * sl.shown / 100); height: parent.height; radius: height / 2; color: "white" }
        Rectangle {
            width: parent.height; height: parent.height; radius: height / 2
            x: Math.max(0, sl.width * sl.shown / 100 - width)
            color: "white"; border.width: 0.5; border.color: Qt.rgba(0, 0, 0, 0.2)
        }
        Text { x: 6; anchors.verticalCenter: parent.verticalCenter; text: sl.glyph; font.pixelSize: 11; color: "#6E6E73" }
        MouseArea {
            id: drag
            anchors.fill: parent
            function upd(mx) { sl.shown = Math.max(0, Math.min(100, mx / sl.width * 100)) }
            onPressed: (e) => upd(e.x)
            onPositionChanged: (e) => { if (pressed) { upd(e.x); if (!liveTimer.running) liveTimer.start() } }
            onReleased: { liveTimer.stop(); sl.moved(sl.shown) }
            Timer { id: liveTimer; interval: 120; onTriggered: sl.moved(sl.shown) }
        }
    }
}
