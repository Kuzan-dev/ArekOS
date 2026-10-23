import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Energía"
    readonly property bool hasBattery: Sys.listDir("/sys/class/power_supply", ["BAT*"], true).length > 0
    readonly property string battery: hasBattery ? Sys.readFile(Sys.listDir("/sys/class/power_supply", ["BAT*"], true)[0] + "/capacity").trim() : ""
    readonly property bool hasPpd: Sys.run("bash", ["-c", "command -v powerprofilesctl"]).trim() !== ""
    readonly property var profiles: ["power-saver", "balanced", "performance"]
    readonly property var mins: [1, 2, 5, 10, 15, 30, 60, 0]
    readonly property var minNames: ["1 minuto", "2 minutos", "5 minutos", "10 minutos", "15 minutos", "30 minutos", "1 hora", "Nunca"]

    function pd(groups, key, def) { return Sys.readConf("powerdevilrc", ["AC"].concat(groups), key, def) }
    function pdw(groups, key, value) {
        Sys.writeConf("powerdevilrc", ["AC"].concat(groups), key, value)
        Sys.detached("dbus-send", ["--session", "--type=method_call", "--dest=org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement", "org.kde.Solid.PowerManagement.reparseConfiguration"])
    }
    function minIndex(sec, enabled) { return enabled === "false" ? mins.length - 1 : idx(mins, Math.round(Number(sec) / 60), 3) }

    Card {
        visible: p.hasBattery
        RowItem { title: "Batería"; tileIcon: "battery-full-symbolic"; tileColor: Theme.tile.green; Txt { text: p.battery + " %"; color: Theme.secondary } }
    }
    Card {
        RowItem {
            title: "Modo de energía"
            subtitle: p.hasPpd ? "" : "Instala power-profiles-daemon para cambiar el modo de energía"
            MacPopup {
                enabled2: p.hasPpd
                model: ["Bajo consumo", "Automático", "Alto rendimiento"]
                currentIndex: p.hasPpd ? p.idx(p.profiles, Sys.run("powerprofilesctl", ["get"]).trim(), 1) : 1
                onActivated: (i) => Sys.run("powerprofilesctl", ["set", p.profiles[i]])
            }
        }
    }
    SectionHeader { text: "Inactividad" }
    Card {
        RowItem {
            title: "Atenuar la pantalla ligeramente al estar inactivo"
            MacSwitch { checked: p.pd(["Display"], "DimDisplayWhenIdle", "true") !== "false"; onToggled: (v) => p.pdw(["Display"], "DimDisplayWhenIdle", v ? "true" : "false") }
        }
        RowItem {
            title: "Atenuar la pantalla tras"
            visible: p.pd(["Display"], "DimDisplayWhenIdle", "true") !== "false"
            MacPopup {
                readonly property var secs: [30, 60, 120, 300, 600]
                model: ["30 segundos", "1 minuto", "2 minutos", "5 minutos", "10 minutos"]
                currentIndex: p.idx(secs, Number(p.pd(["Display"], "DimDisplayIdleTimeoutSec", "300")), 3)
                onActivated: (i) => p.pdw(["Display"], "DimDisplayIdleTimeoutSec", String(secs[i]))
            }
        }
        RowItem {
            title: "Apagar la pantalla tras"
            MacPopup {
                model: p.minNames
                currentIndex: p.minIndex(p.pd(["Display"], "TurnOffDisplayIdleTimeoutSec", "600"), p.pd(["Display"], "TurnOffDisplayWhenIdle", "true"))
                onActivated: (i) => {
                    p.pdw(["Display"], "TurnOffDisplayWhenIdle", p.mins[i] === 0 ? "false" : "true")
                    if (p.mins[i]) p.pdw(["Display"], "TurnOffDisplayIdleTimeoutSec", String(p.mins[i] * 60))
                }
            }
        }
        RowItem {
            title: "Poner el ordenador en reposo tras"
            MacPopup {
                model: p.minNames
                currentIndex: p.minIndex(p.pd(["SuspendAndShutdown"], "AutoSuspendIdleTimeoutSec", "900"), p.pd(["SuspendAndShutdown"], "AutoSuspendAction", "1") === "0" ? "false" : "true")
                onActivated: (i) => {
                    p.pdw(["SuspendAndShutdown"], "AutoSuspendAction", p.mins[i] === 0 ? "0" : "1")
                    if (p.mins[i]) p.pdw(["SuspendAndShutdown"], "AutoSuspendIdleTimeoutSec", String(p.mins[i] * 60))
                }
            }
        }
    }
    SectionHeader { text: "Botón de encendido" }
    Card {
        RowItem {
            title: "Al pulsar el botón de encendido"
            MacPopup {
                readonly property var vals: ["16", "1", "8", "32", "64", "0"]
                model: ["Preguntar qué hacer", "Poner en reposo", "Apagar", "Bloquear la pantalla", "Apagar la pantalla", "No hacer nada"]
                currentIndex: p.idx(vals, p.pd(["SuspendAndShutdown"], "PowerButtonAction", "16"))
                onActivated: (i) => p.pdw(["SuspendAndShutdown"], "PowerButtonAction", vals[i])
            }
        }
        RowItem {
            title: "Bloquear la pantalla al apagarla"
            MacSwitch { checked: p.pd(["Display"], "LockBeforeTurnOffDisplay", "false") === "true"; onToggled: (v) => p.pdw(["Display"], "LockBeforeTurnOffDisplay", v ? "true" : "false") }
        }
    }
    KdeOptions {
        page: p
        items: [
            { t: "Ahorro de energía", s: "Perfiles con corriente, batería y batería baja", k: "kcm_powerdevilprofilesconfig", icon: "battery-full-symbolic" }
        ]
    }
}
