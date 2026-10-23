import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Concentración"
    function r(g, k, d) { return Sys.readConf("plasmanotifyrc", [g], k, d) }
    function w(g, k, v) { Sys.writeConf("plasmanotifyrc", [g], k, v) }
    property bool dnd: {
        const u = r("DoNotDisturb", "Until", "")
        return u !== "" && new Date(u) > new Date()
    }

    Card {
        RowItem {
            title: "No molestar"
            subtitle: "Silencia las notificaciones hasta que lo desactives"
            tileGlyph: "☾"
            tileColor: Theme.tile.indigo
            MacSwitch {
                checked: p.dnd
                onToggled: (v) => { if (v) p.w("DoNotDisturb", "Until", "2099-01-01T00:00:00"); else Sys.deleteConf("plasmanotifyrc", ["DoNotDisturb"], "Until"); p.dnd = v }
            }
        }
    }
    SectionHeader { text: "Activar automáticamente" }
    Card {
        RowItem {
            title: "Al duplicar o compartir la pantalla"
            MacSwitch { checked: p.r("DoNotDisturb", "WhenScreenSharing", "true") === "true"; onToggled: (v) => { p.w("DoNotDisturb", "WhenScreenSharing", v ? "true" : "false"); p.w("DoNotDisturb", "WhenScreensMirrored", v ? "true" : "false") } }
        }
        RowItem {
            title: "Al usar una app a pantalla completa"
            subtitle: "Juegos, vídeos y presentaciones"
            MacSwitch { checked: p.r("DoNotDisturb", "WhenFullscreen", "true") === "true"; onToggled: (v) => p.w("DoNotDisturb", "WhenFullscreen", v ? "true" : "false") }
        }
    }
    SectionHeader { text: "Mientras está activo" }
    Card {
        RowItem {
            title: "Permitir notificaciones urgentes"
            MacSwitch { checked: p.r("Notifications", "CriticalInDndMode", "true") === "true"; onToggled: (v) => p.w("Notifications", "CriticalInDndMode", v ? "true" : "false") }
        }
        RowItem {
            title: "Silenciar los sonidos de las notificaciones"
            MacSwitch { checked: p.r("DoNotDisturb", "NotificationSoundsMuted", "false") === "true"; onToggled: (v) => p.w("DoNotDisturb", "NotificationSoundsMuted", v ? "true" : "false") }
        }
    }
}
