import QtQuick
import QtQuick.Layouts

// General (macOS Sequoia: Información, Actualización, Almacenamiento, AirDrop, Ítems de inicio, Fecha y hora,
// Idioma y región, Apps predeterminadas, Compartir…). Lo que es de KDE se abre dentro de la ventana.
Page {
    id: p
    title: "General"
    Card {
        RowItem { title: "Información"; tileGlyph: "i"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.open("info") }
        RowItem { title: "Actualización de software"; tileIcon: "system-software-update-symbolic"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.kcm("kcm_updates") }
        RowItem { title: "Almacenamiento"; tileIcon: "drive-harddisk-symbolic"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.open("info") }
    }
    Card {
        RowItem { title: "AirDrop y Handoff"; subtitle: "KDE Connect: archivos, portapapeles y notificaciones con el móvil"; tileIcon: "smartphone-symbolic"; tileColor: Theme.tile.blue; chevron: true; onClicked: Sys.detached("kdeconnect-app") }
        RowItem { title: "Ítems de inicio"; subtitle: "Apps que se abren al iniciar sesión"; tileIcon: "view-app-grid-symbolic"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.kcm("kcm_autostart") }
        RowItem { title: "Apps predeterminadas"; subtitle: "Navegador, correo, archivos…"; tileIcon: "application-menu-symbolic"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.kcm("kcm_componentchooser") }
    }
    Card {
        RowItem { title: "Fecha y hora"; tileIcon: "clock-symbolic"; tileColor: Theme.tile.blue; chevron: true; onClicked: p.open("fecha") }
        RowItem { title: "Idioma y región"; tileIcon: "map-globe-symbolic"; tileColor: Theme.tile.blue; chevron: true; onClicked: p.kcm("kcm_regionandlang") }
        RowItem { title: "Tipografías"; tileGlyph: "A"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.kcm("kcm_fonts") }
    }
    Card {
        RowItem { title: "Compartir"; subtitle: "Escritorio remoto (RDP)"; tileIcon: "folder-remote-symbolic"; tileColor: Theme.tile.blue; chevron: true; onClicked: p.kcm("kcm_krdpserver") }
        RowItem { title: "Discos y dispositivos"; subtitle: "Montaje automático"; tileIcon: "drive-removable-media-symbolic"; tileColor: Theme.tile.grey; chevron: true; onClicked: p.kcm("kcm_device_automounter") }
    }
    KdeOptions {
        page: p
        items: [
            { t: "Sesión", s: "Qué hacer al iniciar y cerrar sesión", k: "kcm_smserver", icon: "system-log-out-symbolic" },
            { t: "Comportamiento general", s: "Clic, arrastrar, información emergente", k: "kcm_workspace", icon: "preferences-desktop-symbolic" },
            { t: "Actividades", k: "kcm_activities", icon: "preferences-activities-symbolic" },
            { t: "Apps de inicio de sesión de KDE", s: "Servicios en segundo plano", k: "kcm_kded", icon: "preferences-system-symbolic" },
            { t: "Tipos de archivo", s: "Con qué app se abre cada tipo", k: "kcm_filetypes", icon: "preferences-desktop-filetype-association-symbolic" },
            { t: "Ortografía", k: "kcmspellchecking", icon: "tools-check-spelling-symbolic" },
            { t: "Ajustes del Sistema de KDE", s: "Todos los módulos originales", run: "systemsettings", icon: "preferences-system-symbolic" }
        ]
    }
}
