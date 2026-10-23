import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Spotlight"
    readonly property var runners: [
        { id: "krunner_services", t: "Aplicaciones", icon: "view-app-grid-symbolic", c: "blue" },
        { id: "krunner_systemsettings", t: "Ajustes del Sistema", icon: "preferences-system-symbolic", c: "grey" },
        { id: "baloosearch", t: "Documentos y archivos", icon: "search-symbolic", c: "blue" },
        { id: "krunner_recentdocuments", t: "Documentos recientes", icon: "clock-symbolic", c: "orange" },
        { id: "krunner_placesrunner", t: "Lugares", icon: "drive-harddisk-symbolic", c: "teal" },
        { id: "calculator", t: "Calculadora", glyph: "=", c: "graphite" },
        { id: "unitconverter", t: "Conversiones", glyph: "⇄", c: "orange" },
        { id: "krunner_dictionary", t: "Diccionario", glyph: "Aa", c: "red" },
        { id: "krunner_bookmarksrunner", t: "Marcadores web", icon: "map-globe-symbolic", c: "blue" },
        { id: "krunner_webshortcuts", t: "Búsquedas web", icon: "map-globe-symbolic", c: "indigo" },
        { id: "krunner_shell", t: "Órdenes de terminal", glyph: ">_", c: "black" },
        { id: "krunner_sessions", t: "Sesión (bloquear, apagar…)", icon: "system-lock-screen-symbolic", c: "graphite" }
    ]
    function on(id) { return Sys.readConf("krunnerrc", ["Plugins"], id + "Enabled", "true") === "true" }

    Card {
        RowItem {
            title: "Atajo de teclado"
            subtitle: "También desde la lupa de la barra de menús"
            Txt { text: "Super + Espacio  ·  Alt + Espacio  ·  Super + S"; color: Theme.secondary }
        }
        RowItem {
            title: "Mostrar la lupa de Spotlight en la barra de menús"
            MacSwitch {
                checked: Sys.readConf("vitrumrc", ["Spotlight"], "MenuBarIcon", "true") === "true"
                onToggled: (v) => { Sys.writeConf("vitrumrc", ["Spotlight"], "MenuBarIcon", v ? "true" : "false") }
            }
        }
    }
    SectionHeader { text: "Resultados de búsqueda" }
    Note { text: "Solo las categorías seleccionadas aparecerán en los resultados de Spotlight." }
    Card {
        Repeater {
            model: p.runners
            RowItem {
                title: modelData.t
                hasCheck: true
                checked: p.on(modelData.id)
                tileIcon: modelData.icon || ""
                tileGlyph: modelData.glyph || ""
                tileColor: Theme.tile[modelData.c]
                onCheckToggled: (v) => Sys.writeConf("krunnerrc", ["Plugins"], modelData.id + "Enabled", v ? "true" : "false")
            }
        }
    }
    KdeOptions {
        page: p
        items: [
            { t: "Búsqueda de Plasma", s: "Orden y opciones de cada categoría", k: "kcm_plasmasearch", icon: "search-symbolic" },
            { t: "Indexado de archivos", s: "Carpetas que se incluyen o excluyen", k: "kcm_baloofile", icon: "drive-harddisk-symbolic" },
            { t: "Búsquedas web", s: "Atajos como «gg:» o «wp:»", k: "kcm_webshortcuts", icon: "map-globe-symbolic" }
        ]
    }
}
