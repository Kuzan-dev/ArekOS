import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Pantalla de bloqueo"
    function r(k, d) { return Sys.readConf("kscreenlockerrc", ["Daemon"], k, d) }
    function w(k, v) {
        Sys.writeConf("kscreenlockerrc", ["Daemon"], k, v)
        Sys.detached("dbus-send", ["--session", "--type=method_call", "--dest=org.freedesktop.ScreenSaver", "/ScreenSaver", "org.kde.screensaver.configure"])
    }
    readonly property var mins: ["1", "2", "5", "10", "15", "30", "60"]
    readonly property var graces: ["0", "5", "60", "300", "900"]

    Card {
        RowItem {
            title: "Bloquear la pantalla automáticamente tras"
            MacPopup {
                model: ["Nunca", "1 minuto", "2 minutos", "5 minutos", "10 minutos", "15 minutos", "30 minutos", "1 hora"]
                currentIndex: p.r("Autolock", "true") === "false" ? 0 : p.idx(p.mins, p.r("Timeout", "5"), 2) + 1
                onActivated: (i) => { p.w("Autolock", i === 0 ? "false" : "true"); if (i > 0) p.w("Timeout", p.mins[i - 1]) }
            }
        }
        RowItem {
            title: "Solicitar la contraseña tras el bloqueo"
            MacPopup {
                model: ["Inmediatamente", "Tras 5 segundos", "Tras 1 minuto", "Tras 5 minutos", "Tras 15 minutos"]
                currentIndex: p.idx(p.graces, p.r("LockGrace", "5"), 1)
                onActivated: (i) => p.w("LockGrace", p.graces[i])
            }
        }
        RowItem {
            title: "Bloquear al salir del reposo"
            MacSwitch { checked: p.r("LockOnResume", "true") === "true"; onToggled: (v) => p.w("LockOnResume", v ? "true" : "false") }
        }
    }
    // macOS Sequoia pone aquí cuándo se apaga la pantalla (PowerDevil, perfil con corriente)
    Card {
        RowItem {
            title: "Apagar la pantalla tras"
            MacPopup {
                readonly property var mins: [1, 2, 5, 10, 15, 30, 60, 0]
                model: ["1 minuto", "2 minutos", "5 minutos", "10 minutos", "15 minutos", "30 minutos", "1 hora", "Nunca"]
                currentIndex: Sys.readConf("powerdevilrc", ["AC", "Display"], "TurnOffDisplayWhenIdle", "true") === "false" ? 7
                              : p.idx(mins, Math.round(Number(Sys.readConf("powerdevilrc", ["AC", "Display"], "TurnOffDisplayIdleTimeoutSec", "600")) / 60), 3)
                onActivated: (i) => {
                    Sys.writeConf("powerdevilrc", ["AC", "Display"], "TurnOffDisplayWhenIdle", mins[i] === 0 ? "false" : "true")
                    if (mins[i]) Sys.writeConf("powerdevilrc", ["AC", "Display"], "TurnOffDisplayIdleTimeoutSec", String(mins[i] * 60))
                    Sys.detached("dbus-send", ["--session", "--type=method_call", "--dest=org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement", "org.kde.Solid.PowerManagement.reparseConfiguration"])
                }
            }
        }
        RowItem {
            title: "Mostrar los controles de reproducción en la pantalla bloqueada"
            MacSwitch {
                checked: Sys.readConf("kscreenlockerrc", ["Greeter", "LnF", "General"], "showMediaControls", "true") === "true"
                onToggled: (v) => Sys.writeConf("kscreenlockerrc", ["Greeter", "LnF", "General"], "showMediaControls", v ? "true" : "false")
            }
        }
    }
    KdeOptions {
        page: p
        items: [
            { t: "Pantalla de bloqueo", s: "Fondo, reloj y opciones de KDE", k: "kcm_screenlocker", icon: "system-lock-screen-symbolic" },
            { t: "Cambiar la contraseña", k: "kcm_users", icon: "system-users-symbolic" }
        ]
    }
}
