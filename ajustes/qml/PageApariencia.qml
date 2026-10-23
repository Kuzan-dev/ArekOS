import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Apariencia"

    property string modo: Sys.readConf("vitrumrc", ["Apariencia"], "Modo", Theme.dark ? "oscuro" : "claro")
    readonly property var acentos: [
        { name: "Multicolor", c: "" }, { name: "Azul", c: "#007AFF" }, { name: "Morado", c: "#A550A7" },
        { name: "Rosa", c: "#F74F9E" }, { name: "Rojo", c: "#FF5257" }, { name: "Naranja", c: "#F7821B" },
        { name: "Amarillo", c: "#FFC600" }, { name: "Verde", c: "#62BA46" }, { name: "Grafito", c: "#8C8C8C" }
    ]
    property string acento: {
        const a = Sys.readConf("kdeglobals", ["General"], "AccentColor", "")
        if (!a) return ""
        const v = a.split(",").map(Number)
        return "#" + v.map(x => ("0" + x.toString(16)).slice(-2)).join("").toUpperCase()
    }
    function aplicarModo(m) {
        modo = m
        Sys.runAsync("modo", Sys.home() + "/.local/bin/vitrum-modo", [m, "--aplicar"])
    }
    function aplicarAcento(c) {
        acento = c
        if (c === "") Sys.deleteConf("kdeglobals", ["General"], "AccentColor")
        const esquema = Theme.dark ? "VitrumDark" : "VitrumLight"
        Sys.runAsync("acento", "plasma-apply-colorscheme", c ? [esquema, "--accent-color", c] : [esquema])
    }
    Connections {
        target: Sys
        function onFinished(tag) { if (tag === "modo" || tag === "acento") Theme.refresh() }
    }

    readonly property bool menusTranslucidos: Number(Sys.readConf("darklyrc", ["Style"], "MenuOpacity", "55")) < 100

    Card {
        RowItem {
            title: "Aspecto"
            minHeight: 84
            Row {
                spacing: 14
                ModeThumb { mode: "claro"; label: "Claro"; selected: p.modo === "claro"; onClicked: p.aplicarModo("claro") }
                ModeThumb { mode: "oscuro"; label: "Oscuro"; selected: p.modo === "oscuro"; onClicked: p.aplicarModo("oscuro") }
                ModeThumb { mode: "auto"; label: "Automático"; selected: p.modo === "auto"; onClicked: p.aplicarModo("auto") }
            }
        }
    }
    Note { text: "Automático usa el aspecto claro durante el día (7:00–19:00) y el oscuro por la noche." }

    SectionHeader { text: "Tema" }
    Card {
        RowItem {
            title: "Color de acento"
            minHeight: 58
            Column {
                spacing: 4
                Row {
                    spacing: 10
                    Repeater {
                        model: p.acentos
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            gradient: modelData.c === "" ? multi : null
                            color: modelData.c || "transparent"
                            border.width: p.acento === modelData.c ? 2.5 : 0.5
                            border.color: p.acento === modelData.c ? Theme.windowBg : Qt.rgba(0, 0, 0, 0.15)
                            Rectangle {
                                visible: p.acento === modelData.c
                                anchors.centerIn: parent; width: 24; height: 24; radius: 12
                                color: "transparent"; border.width: 2; border.color: Theme.dark ? "#888" : "#BBB"
                            }
                            Gradient {
                                id: multi
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "#FF5257" }
                                GradientStop { position: 0.33; color: "#FFC600" }
                                GradientStop { position: 0.66; color: "#62BA46" }
                                GradientStop { position: 1; color: "#007AFF" }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: p.aplicarAcento(modelData.c) }
                        }
                    }
                }
                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                    text: (p.acentos.find(a => a.c === p.acento) || { name: "Personalizado" }).name
                    font.pixelSize: Theme.smallSize; color: Theme.secondary
                }
            }
        }
        RowItem {
            title: "Menús translúcidos"
            subtitle: "Los menús dejan ver el fondo desenfocado, como en macOS"
            MacSwitch {
                checked: p.menusTranslucidos
                onToggled: (v) => Sys.writeConf("darklyrc", ["Style"], "MenuOpacity", v ? "55" : "100")
            }
        }
    }

    Card {
        RowItem {
            title: "Tamaño de los iconos de la barra lateral"
            MacPopup {
                readonly property var vals: ["16", "22", "32"]
                model: ["Pequeño", "Mediano", "Grande"]
                currentIndex: p.idx(vals, Sys.readConf("dolphinrc", ["PlacesPanel"], "IconSize", "16"))
                onActivated: (i) => Sys.writeConf("dolphinrc", ["PlacesPanel"], "IconSize", vals[i])
            }
        }
        RowItem {
            title: "Permitir que el fondo de pantalla tiña las ventanas"
            subtitle: "Barras laterales y menús translúcidos, como en macOS"
            MacSwitch {
                checked: Number(Sys.readConf("darklyrc", ["Style"], "DolphinSidebarOpacity", "78")) < 100
                onToggled: (v) => Sys.writeConf("darklyrc", ["Style"], "DolphinSidebarOpacity", v ? "78" : "100")
            }
        }
    }
    Card {
        RadioGroup {
            title: "Mostrar las barras de desplazamiento"
            separatorVisible: false
            options: ["Automáticamente, según el ratón o el trackpad", "Al desplazarse", "Siempre"]
            current: Sys.readConf("darklyrc", ["Common"], "ScrollBarTransient", "false") === "true" ? 0 : 2
            onPicked: (i) => Sys.writeConf("darklyrc", ["Common"], "ScrollBarTransient", i === 2 ? "false" : "true")
        }
        RadioGroup {
            title: "Al hacer clic en la barra de desplazamiento"
            options: ["Ir a la página siguiente", "Ir a donde se ha hecho clic"]
            current: Sys.readConf("kdeglobals", ["KDE"], "ScrollbarLeftClickNavigatesByPage", "true") === "true" ? 0 : 1
            onPicked: (i) => Sys.writeConf("kdeglobals", ["KDE"], "ScrollbarLeftClickNavigatesByPage", i === 0 ? "true" : "false")
        }
    }
    Note { text: "Los cambios de estilo se aplican a las apps que abras a partir de ahora." }

    SectionHeader { text: "Archivos" }
    Card {
        RowItem {
            title: "Abrir archivos y carpetas con"
            MacPopup {
                model: ["Doble clic", "Un clic"]
                currentIndex: Sys.readConf("kdeglobals", ["KDE"], "SingleClick", "false") === "true" ? 1 : 0
                onActivated: (i) => Sys.writeConf("kdeglobals", ["KDE"], "SingleClick", i === 1 ? "true" : "false")
            }
        }
        RowItem {
            title: "Tipografías del sistema…"
            chevron: true
            onClicked: p.kcm("kcm_fonts")
        }
    }

    KdeOptions {
        page: p
        items: [
            { t: "Colores", s: "Esquemas de color completos", k: "kcm_colors", icon: "color-management-symbolic" },
            { t: "Tema global", k: "kcm_lookandfeel", icon: "preferences-desktop-theme-global-symbolic" },
            { t: "Estilo de Plasma", s: "Barra de menús, menús y paneles", k: "kcm_desktoptheme", icon: "preferences-desktop-plasma-theme-symbolic" },
            { t: "Estilo de las apps", k: "kcm_style", icon: "preferences-desktop-theme-applications-symbolic" },
            { t: "Decoración de las ventanas", s: "Semáforos y bordes", k: "kcm_kwindecoration", icon: "preferences-desktop-theme-windowdecorations-symbolic" },
            { t: "Iconos", k: "kcm_icons", icon: "preferences-desktop-icons-symbolic" },
            { t: "Cursores", k: "kcm_cursortheme", icon: "preferences-desktop-cursors-symbolic" },
            { t: "Tipografías", k: "kcm_fonts", icon: "preferences-desktop-font-symbolic" },
            { t: "Pantalla de bienvenida", k: "kcm_splashscreen", icon: "preferences-desktop-splash-screen-symbolic" },
            { t: "Animaciones y efectos", k: "kcm_kwin_effects", icon: "preferences-desktop-effects-symbolic" }
        ]
    }
}
