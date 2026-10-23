import QtQuick
import QtQuick.Layouts

// Fecha y hora (macOS Sequoia): ajuste automático, zona horaria y formato de 24 horas.
// timedatectl pide la contraseña del administrador cuando hace falta (polkit), como macOS.
Page {
    id: p
    title: "Fecha y hora"
    property var info: ({})
    function refresh() {
        const o = {}
        for (const l of Sys.run("timedatectl", ["show"]).split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1) }
        info = o
    }
    Component.onCompleted: refresh()
    readonly property var zones: Sys.run("timedatectl", ["list-timezones"], 6000).split("\n").filter(x => x)
    Connections { target: Sys; function onFinished(tag) { if (tag === "fecha") p.refresh() } }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: now.text = new Date().toLocaleString(Qt.locale(), Locale.LongFormat) }

    Card {
        RowItem {
            title: "Ajustar la fecha y la hora automáticamente"
            subtitle: "Mediante servidores de hora de internet"
            MacSwitch { checked: p.info.NTP === "yes"; onToggled: (v) => Sys.runAsync("fecha", "timedatectl", ["set-ntp", v ? "true" : "false"]) }
        }
        RowItem { title: "Fecha y hora"; Txt { id: now; color: Theme.secondary } }
    }
    Card {
        RowItem {
            title: "Zona horaria"
            MacPopup {
                model: p.zones.map(z => z.replace(/_/g, " "))
                currentIndex: Math.max(0, p.zones.indexOf(p.info.Timezone))
                onActivated: (i) => Sys.runAsync("fecha", "timedatectl", ["set-timezone", p.zones[i]])
            }
        }
        RowItem {
            title: "Usar el formato de 24 horas"
            subtitle: "En el reloj de la barra de menús"
            MacSwitch {
                readonly property var clock: {
                    const rc = "plasma-org.kde.plasma.desktop-appletsrc"
                    for (const c of Sys.confGroups(rc, ["Containments"]))
                        for (const a of Sys.confGroups(rc, ["Containments", c, "Applets"]))
                            if (Sys.readConf(rc, ["Containments", c, "Applets", a], "plugin") === "org.kde.plasma.digitalclock") return [c, a]
                    return null
                }
                checked: clock ? Sys.readConf("plasma-org.kde.plasma.desktop-appletsrc", ["Containments", clock[0], "Applets", clock[1], "Configuration", "Appearance"], "use24hFormat", "2") === "2" : true
                onToggled: (v) => { if (clock) Sys.detached(Sys.home() + "/.local/bin/vitrum-plasma-set", ["Containments/" + clock[0] + "/Applets/" + clock[1] + "/Configuration/Appearance;use24hFormat;" + (v ? "2" : "0")]) }
            }
        }
    }
    KdeOptions {
        page: p
        items: [
            { t: "Fecha y hora", s: "Servidores de hora y ajuste manual", k: "kcm_clock", icon: "clock-symbolic" },
            { t: "Formatos", s: "Fechas, números y moneda", k: "kcm_regionandlang", icon: "map-globe-symbolic" }
        ]
    }
}
