import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

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
    // Pantalla de inicio de sesión: es común a todos los usuarios y la dibuja Plasma Login, así que usa una imagen
    // fija (no los fondos animados de waywallen); cambiarla pide la contraseña de administrador
    SectionHeader { text: "Pantalla de inicio de sesión"; visible: Sys.exists("/usr/local/libexec/vitrum-login-fondo") }
    Card {
        visible: Sys.exists("/usr/local/libexec/vitrum-login-fondo")
        Item {
            Layout.fillWidth: true
            implicitHeight: 112
            property int rev: 0
            readonly property string actual: {
                rev
                const m = Sys.readText("/etc/plasmalogin.conf").match(/^Image=(.+)$/m)
                return m ? m[1].trim() : ""
            }
            // imagen fija del escritorio (si el escritorio usa waywallen, la última imagen que tuvo)
            readonly property string escritorio: {
                const m = Sys.readText(Sys.home() + "/.config/plasma-org.kde.plasma.desktop-appletsrc").match(/^Image=(.+)$/m)
                return m ? m[1].trim() : ""
            }
            id: loginBg
            RowLayout {
                anchors.fill: parent; anchors.margins: 14
                spacing: 14
                Rectangle {
                    Layout.preferredWidth: 136; Layout.preferredHeight: 84
                    radius: 6; color: "#0b0b0d"
                    border.width: 1; border.color: Theme.cardEdge
                    Image {
                        anchors.fill: parent; anchors.margins: 3
                        source: loginBg.actual ? loginBg.actual + "?v=" + loginBg.rev : ""
                        cache: false; fillMode: Image.PreserveAspectCrop; sourceSize.width: 300; asynchronous: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Txt { text: "Fondo"; font.weight: Font.DemiBold }
                    Txt {
                        Layout.fillWidth: true
                        text: "Es la misma para todas las cuentas y usa una imagen fija: los fondos animados solo están en tu escritorio y tu pantalla de bloqueo."
                        color: Theme.secondary; font.pixelSize: Theme.smallSize; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    }
                    RowLayout {
                        spacing: 8
                        MacButton { text: "Elegir imagen…"; onClicked: loginPicker.open() }
                        MacButton {
                            text: "Usar la del escritorio"
                            visible: loginBg.escritorio !== "" && loginBg.escritorio !== loginBg.actual
                            onClicked: p.setLoginBg(loginBg.escritorio)
                        }
                    }
                }
            }
            Connections {
                target: Sys
                function onFinished(tag) { if (tag === "login-fondo") loginBg.rev++ }
            }
        }
    }
    function setLoginBg(url) {
        const path = String(url).replace(/^file:\/\//, "")
        Sys.runAsync("login-fondo", "pkexec", ["/usr/local/libexec/vitrum-login-fondo", decodeURIComponent(path)])
    }
    FileDialog {
        id: loginPicker
        title: "Fondo de la pantalla de inicio de sesión"
        nameFilters: ["Imágenes (*.jpg *.jpeg *.png *.webp)"]
        currentFolder: "file://" + Sys.home() + "/Imágenes"
        onAccepted: p.setLoginBg(String(selectedFile))
    }

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
