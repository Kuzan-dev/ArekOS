import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Barra de menús"
    readonly property string rc: "plasma-org.kde.plasma.desktop-appletsrc"

    // Busca un applet por plugin en los paneles: devuelve [contenedor, applet]
    function findApplet(plugin) {
        for (const c of Sys.confGroups(rc, ["Containments"]))
            for (const a of Sys.confGroups(rc, ["Containments", c, "Applets"]))
                if (Sys.readConf(rc, ["Containments", c, "Applets", a], "plugin") === plugin) return [c, a]
        return null
    }
    readonly property var clock: findApplet("org.kde.plasma.digitalclock")
    // Plasma 6: la bandeja está anidada en el panel (Containments/<panel>/Applets/<bandeja>)
    readonly property var tray: findApplet("org.kde.plasma.systemtray") || ["", ""]
    function trayList(key) { return Sys.readConf(rc, ["Containments", tray[0], "Applets", tray[1], "General"], key, "").split(",").filter(x => x) }
    property var enabledItems: trayList("extraItems")

    readonly property var controls: [
        { id: "org.kde.plasma.networkmanagement", t: "Red", icon: "network-wireless-symbolic", c: "blue" },
        { id: "org.kde.plasma.bluetooth", t: "Bluetooth", icon: "network-bluetooth-symbolic", c: "blue" },
        { id: "org.kde.plasma.volume", t: "Sonido", icon: "audio-volume-high-symbolic", c: "pink" },
        { id: "org.kde.plasma.battery", t: "Energía", icon: "battery-full-symbolic", c: "green" },
        { id: "org.kde.plasma.brightness", t: "Pantalla", icon: "brightness-high-symbolic", c: "blue" },
        { id: "org.kde.plasma.mediacontroller", t: "Reproduciendo", icon: "audio-speakers-symbolic", c: "pink" },
        { id: "org.kde.plasma.keyboardlayout", t: "Teclado", icon: "input-keyboard-symbolic", c: "grey" },
        { id: "org.kde.plasma.clipboard", t: "Portapapeles", icon: "edit-paste-symbolic", c: "grey" },
        { id: "org.kde.plasma.devicenotifier", t: "Discos", icon: "drive-harddisk-symbolic", c: "grey" },
        { id: "org.kde.kdeconnect", t: "KDE Connect", icon: "network-wireless-symbolic", c: "blue" },
        { id: "org.kde.plasma.printmanager", t: "Impresoras", icon: "printer-symbolic", c: "grey" }
    ]
    function setShown(id, on) {
        let list = enabledItems.filter(x => x !== id)
        if (on) list = list.concat([id])
        enabledItems = list
        trayTimer.restart()
    }
    Timer { id: trayTimer; interval: 1500; onTriggered: Sys.detached(Sys.home() + "/.local/bin/vitrum-bandeja", [p.enabledItems.join(",")]) }
    // Las opciones de reloj y bandeja necesitan reiniciar Plasma: se agrupan y aplican juntas
    property var pending: ({})
    function clockSet(key, value) {
        pending["Containments/" + clock[0] + "/Applets/" + clock[1] + "/Configuration/Appearance;" + key] = value
        applyTimer.restart()
    }
    Timer {
        id: applyTimer
        interval: 1500
        onTriggered: {
            const args = []
            for (const k in p.pending) {
                args.push(k + ";" + p.pending[k])
            }
            p.pending = {}
            Sys.detached(Sys.home() + "/.local/bin/vitrum-plasma-set", args)
        }
    }
    function clockConf(key, def) { return clock ? Sys.readConf(rc, ["Containments", clock[0], "Applets", clock[1], "Configuration", "Appearance"], key, def) : def }

    // estado real de la barra (Plasma lo da por su interfaz de scripts)
    property var barState: {
        const out = Sys.run("qdbus-qt6", ["org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript",
            "print(panels().filter(function(x){ return x.location == 'top' }).map(function(x){ return x.hiding + '|' + x.opacity }).join(','))"]).trim()
        const f = out.split(",")[0].split("|")
        return { hiding: f[0] || "none", opacity: f[1] || "translucent" }
    }
    Card {
        RowItem {
            title: "Ocultar y mostrar automáticamente la barra de menús"
            MacPopup {
                model: ["Siempre", "Al cubrirla una ventana", "Nunca"]
                readonly property var vals: ["autohide", "dodgewindows", "none"]
                currentIndex: p.idx(vals, p.barState.hiding, 2)
                onActivated: (i) => p.plasmaScript("panels().forEach(function(x){ if (x.location == 'top') x.hiding = '" + vals[i] + "' })")
            }
        }
        RowItem {
            title: "Mostrar el fondo de la barra de menús"
            subtitle: "Barra opaca en vez de translúcida"
            MacSwitch {
                checked: p.barState.opacity === "opaque"
                onToggled: (v) => p.plasmaScript("panels().forEach(function(x){ if (x.location == 'top') x.opacity = '" + (v ? "opaque" : "translucent") + "' })")
            }
        }
        RowItem {
            title: "Documentos, apps y servidores recientes"
            MacPopup {
                readonly property var vals: ["0", "5", "10", "15", "20", "30", "50"]
                model: ["Ninguno", "5", "10", "15", "20", "30", "50"]
                currentIndex: p.idx(vals, Sys.readConf("kdeglobals", ["RecentDocuments"], "MaxEntries", "10"), 2)
                onActivated: (i) => Sys.writeConf("kdeglobals", ["RecentDocuments"], "MaxEntries", vals[i])
            }
        }
    }

    SectionHeader { text: "Controles de la barra de menús" }
    Card {
        RowItem {
            minHeight: 64
            title: ""
            subtitle: "Wi‑Fi, sonido, pantalla y el resto ya están en el Centro de Control. Marca los que también quieras ver en la barra de menús."
            Grid {
                columns: 3; spacing: 4; opacity: 0.35
                Repeater { model: 6; Rectangle { width: index % 3 === 0 ? 30 : 14; height: 14; radius: 7; color: Theme.secondary } }
            }
        }
    }
    Card {
        RowItem {
            title: "Reloj"
            tileIcon: "clock-symbolic"
            tileColor: Theme.tile.grey
            MacButton { text: "Opciones del reloj…"; onClicked: clockOpts.visible = !clockOpts.visible }
        }
        ColumnLayout {
            id: clockOpts
            visible: false
            Layout.fillWidth: true
            spacing: 0
            property bool separatorVisible: true
            RowItem {
                title: "Mostrar la fecha"
                MacSwitch { checked: p.clockConf("showDate", "true") === "true"; onToggled: (v) => p.clockSet("showDate", v ? "true" : "false") }
            }
            RowItem {
                title: "Mostrar el día de la semana"
                MacSwitch {
                    checked: p.clockConf("customDateFormat", "ddd d MMM").indexOf("ddd") >= 0
                    onToggled: (v) => { p.clockSet("dateFormat", "custom"); p.clockSet("customDateFormat", v ? "ddd d MMM" : "d MMM") }
                }
            }
            RowItem {
                title: "Usar el reloj de 24 horas"
                MacSwitch { checked: p.clockConf("use24hFormat", "2") === "2"; onToggled: (v) => p.clockSet("use24hFormat", v ? "2" : "0") }
            }
            RowItem {
                title: "Mostrar los segundos"
                MacSwitch { checked: p.clockConf("showSeconds", "0") === "2"; onToggled: (v) => p.clockSet("showSeconds", v ? "2" : "0") }
            }
        }
        Repeater {
            model: p.controls
            RowItem {
                title: modelData.t
                hasCheck: true
                checked: p.enabledItems.indexOf(modelData.id) >= 0
                tileIcon: modelData.icon
                tileColor: Theme.tile[modelData.c]
                onCheckToggled: (v) => p.setShown(modelData.id, v)
                Txt { text: p.enabledItems.indexOf(modelData.id) >= 0 ? "Mostrar en la barra" : "En el Centro de Control"; color: Theme.secondary }
            }
        }
    }
    Note { text: "Al cambiar el reloj o los controles, la barra de menús se reinicia un instante." }

    KdeOptions {
        page: p
        items: [
            { t: "Fecha y hora", s: "Zona horaria y sincronización", k: "kcm_clock", icon: "clock-symbolic" }
        ]
    }
}
