import QtQuick
import QtQuick.Layouts

// Páginas que se apoyan en los módulos de KDE, con algunos ajustes rápidos propios.
Page {
    id: p
    readonly property var pages: ({
        privacidad: { title: "Privacidad y seguridad", rows: [
            { t: "Permisos de las apps", k: "kcm_app-permissions", icon: "security-high-symbolic" },
            { t: "Archivos e historial recientes", k: "kcm_recentFiles", icon: "clock-symbolic" },
            { t: "Búsqueda de archivos", k: "kcm_baloofile", icon: "search-symbolic" },
            { t: "Pantalla de bloqueo", go: "bloqueo", icon: "system-lock-screen-symbolic" } ] },
        usuarios: { title: "Usuarios y grupos", rows: [
            { t: "Cuentas de usuario", s: "Nombre, foto y contraseña", k: "kcm_users", icon: "system-users-symbolic" },
            { t: "Cuentas en línea", k: "kcm_kaccounts", icon: "map-globe-symbolic" } ] },
        contrasenas: { title: "Contraseñas", rows: [
            { t: "Cartera de KDE (llavero)", s: "Contraseñas guardadas de Wi‑Fi, navegadores y apps", run: "kwalletmanager5", icon: "password-copy-symbolic" },
            { t: "Ajustes de la cartera", k: "kcm_kwallet5", icon: "preferences-system-symbolic" } ] },
        impresoras: { title: "Impresoras y escáneres", rows: [
            { t: "Impresoras", s: "Añadir y gestionar impresoras", k: "kcm_printer_manager", icon: "printer-symbolic" } ] }
    })
    readonly property var d: pages[pageId] || { title: "", rows: [] }
    title: d.title

    Card {
        Repeater {
            model: p.d.rows
            RowItem {
                title: modelData.t
                subtitle: modelData.s || ""
                tileIcon: modelData.icon || ""
                tileColor: Theme.tile.blue
                chevron: !!(modelData.k || modelData.go || modelData.run)
                onClicked: modelData.k ? p.kcm(modelData.k) : modelData.go ? p.open(modelData.go) : Sys.detached(modelData.run)
                MacSwitch {
                    visible: !!modelData.sw
                    checked: modelData.sw ? Sys.readConf(modelData.sw[0], modelData.sw[1], modelData.sw[2], modelData.sw[4]) === modelData.sw[3] : false
                    onToggled: (v) => Sys.writeConf(modelData.sw[0], modelData.sw[1], modelData.sw[2], v ? modelData.sw[3] : modelData.sw[4])
                }
                MacPopup {
                    visible: !!modelData.popup
                    model: modelData.popup ? modelData.popup[4] : []
                    currentIndex: modelData.popup ? p.idx(modelData.popup[3], Sys.readConf(modelData.popup[0], modelData.popup[1], modelData.popup[2], modelData.popup[5])) : 0
                    onActivated: (i) => Sys.writeConf(modelData.popup[0], modelData.popup[1], modelData.popup[2], modelData.popup[3][i])
                }
            }
        }
    }
}
