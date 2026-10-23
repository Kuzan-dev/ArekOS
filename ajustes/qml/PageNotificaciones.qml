import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Notificaciones"
    function r(g, k, d) { return Sys.readConf("plasmanotifyrc", [g], k, d) }
    function w(g, k, v) { Sys.writeConf("plasmanotifyrc", [g], k, v) }
    readonly property var positions: ["TopRight", "TopCenter", "TopLeft", "BottomRight", "BottomCenter", "BottomLeft", "CloseToWidget"]
    readonly property var timeouts: ["3000", "5000", "7000", "10000", "15000"]

    SectionHeader { text: "Centro de notificaciones" }
    Card {
        RowItem {
            title: "Mostrar las notificaciones en"
            MacPopup {
                model: ["Arriba a la derecha", "Arriba en el centro", "Arriba a la izquierda", "Abajo a la derecha", "Abajo en el centro", "Abajo a la izquierda", "Junto al reloj"]
                currentIndex: p.idx(p.positions, p.r("Notifications", "PopupPosition", "CloseToWidget"), 6)
                onActivated: (i) => p.w("Notifications", "PopupPosition", p.positions[i])
            }
        }
        RowItem {
            title: "Ocultar las notificaciones tras"
            MacPopup {
                model: ["3 segundos", "5 segundos", "7 segundos", "10 segundos", "15 segundos"]
                currentIndex: p.idx(p.timeouts, p.r("Notifications", "PopupTimeout", "5000"), 1)
                onActivated: (i) => p.w("Notifications", "PopupTimeout", p.timeouts[i])
            }
        }
        RowItem {
            title: "Mostrar notificaciones de baja prioridad"
            MacSwitch { checked: p.r("Notifications", "LowPriorityPopups", "true") === "true"; onToggled: (v) => p.w("Notifications", "LowPriorityPopups", v ? "true" : "false") }
        }
        RowItem {
            title: "Mostrar contadores en los iconos del Dock"
            MacSwitch { checked: p.r("Badges", "InTaskManager", "true") === "true"; onToggled: (v) => p.w("Badges", "InTaskManager", v ? "true" : "false") }
        }
        RowItem {
            title: "Mostrar el progreso de copias y descargas"
            MacSwitch { checked: p.r("Jobs", "InNotifications", "true") === "true"; onToggled: (v) => p.w("Jobs", "InNotifications", v ? "true" : "false") }
        }
    }
    SectionHeader { text: "Notificaciones de las apps" }
    Card {
        RowItem { title: "Configurar cada app"; subtitle: "Sonidos, avisos y permisos por aplicación"; tileIcon: "preferences-desktop-notification-symbolic"; tileColor: Theme.tile.red; chevron: true; onClicked: p.kcm("kcm_notifications") }
    }
}
