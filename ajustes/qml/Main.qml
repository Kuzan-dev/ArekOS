import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC

Window {
    id: win
    width: 790
    height: 650
    minimumWidth: 660
    minimumHeight: 440
    visible: true
    title: currentTitle
    color: "transparent"

    // Sequoia: barra lateral pegada al borde y a toda la altura, separada por una línea
    readonly property int winRadius: 10
    readonly property int sidebarWidth: 220

    // Secciones (id, título, icono, color, palabras clave para buscar)
    readonly property var sections: [
        { id: "wifi", title: "Wi‑Fi", icon: "network-wireless-symbolic", color: "blue", keys: "wifi red inalámbrica" },
        { id: "bluetooth", title: "Bluetooth", icon: "network-bluetooth-symbolic", color: "blue", keys: "dispositivos" },
        { id: "red", title: "Red", icon: "map-globe-symbolic", color: "blue", keys: "ethernet ip cable" },
        { id: "vpn", title: "VPN", icon: "network-vpn-symbolic", color: "blue", keys: "wireguard" },
        { id: "energia", title: "Energía", icon: "battery-full-symbolic", color: "green", keys: "batería suspender reposo rendimiento" },
        { sep: true },
        { id: "general", title: "General", icon: "preferences-system-symbolic", color: "grey", keys: "información fecha hora idioma inicio almacenamiento actualización" },
        { id: "accesibilidad", title: "Accesibilidad", icon: "preferences-desktop-accessibility-symbolic", color: "blue", keys: "zoom contraste" },
        { id: "apariencia", title: "Apariencia", icon: "color-mode-black-white-symbolic", color: "black", keys: "oscuro claro tema color acento" },
        { id: "barra", title: "Barra de menús", icon: "application-menu-symbolic", color: "grey", keys: "reloj panel superior" },
        { id: "dock", title: "Escritorio y Dock", icon: "view-app-grid-symbolic", color: "black", keys: "dock minimizar ventanas" },
        { id: "pantallas", title: "Pantallas", icon: "monitor-symbolic", color: "blue", keys: "resolución escala monitor hdr luz nocturna" },
        { id: "spotlight", title: "Spotlight", icon: "search-symbolic", color: "blue", keys: "krunner buscar" },
        { id: "fondo", title: "Fondo de pantalla", glyph: "✿", color: "teal", keys: "wallpaper imagen" },
        { sep: true },
        { id: "notificaciones", title: "Notificaciones", icon: "notifications-symbolic", color: "red", keys: "avisos" },
        { id: "sonido", title: "Sonido", icon: "audio-volume-high-symbolic", color: "pink", keys: "volumen altavoces micrófono" },
        { id: "concentracion", title: "Concentración", glyph: "☾", color: "indigo", keys: "no molestar" },
        { sep: true },
        { id: "bloqueo", title: "Pantalla de bloqueo", icon: "system-lock-screen-symbolic", color: "black", keys: "contraseña bloquear" },
        { id: "privacidad", title: "Privacidad y seguridad", icon: "security-high-symbolic", color: "blue", keys: "permisos" },
        { id: "usuarios", title: "Usuarios y grupos", icon: "system-users-symbolic", color: "blue", keys: "cuentas" },
        { id: "contrasenas", title: "Contraseñas", icon: "password-copy-symbolic", color: "grey", keys: "kwallet llavero" },
        { sep: true },
        { id: "teclado", title: "Teclado", icon: "input-keyboard-symbolic", color: "grey", keys: "atajos distribución" },
        { id: "raton", title: "Ratón y trackpad", icon: "input-mouse-symbolic", color: "grey", keys: "puntero trackpad desplazamiento natural clic" },
        { id: "impresoras", title: "Impresoras y escáneres", icon: "printer-symbolic", color: "grey", keys: "imprimir" }
    ]
    readonly property var pageFiles: ({
        wifi: "PageWifi", bluetooth: "PageBluetooth", red: "PageRed", vpn: "PageVpn", energia: "PageEnergia",
        general: "PageGeneral", info: "PageInfo", fecha: "PageFecha", accesibilidad: "PageAccesibilidad", apariencia: "PageApariencia",
        barra: "PageBarra", dock: "PageDock", pantallas: "PagePantallas", spotlight: "PageSpotlight",
        fondo: "PageFondo", notificaciones: "PageNotificaciones", sonido: "PageSonido",
        concentracion: "PageConcentracion", bloqueo: "PageBloqueo", privacidad: "PageKcm", usuarios: "PageKcm",
        contrasenas: "PageKcm", teclado: "PageTeclado", raton: "PageRaton", impresoras: "PageKcm"
    })

    property string current: ""
    property var history: []
    property int histIndex: -1
    property string currentTitle: "Ajustes del Sistema"

    function sectionById(id) {
        for (const s of sections) if (s.id === id) return s
        return null
    }
    // sección resaltada en la barra lateral (las páginas de KDE y las subpáginas mantienen la de origen)
    property string section: ""
    function go(id, pushHistory) {
        const kde = id.indexOf("kde:") === 0
        if ((!pageFiles[id] && !kde) || id === current) return
        if (pushHistory !== false) {
            history = history.slice(0, histIndex + 1).concat([id])
            histIndex = history.length - 1
        }
        current = id
        if (!kde) section = id === "info" || id === "fecha" ? "general" : id
        loader.setSource(kde ? "PageKde.qml" : pageFiles[id] + ".qml", { pageId: id })
    }
    function back() { if (histIndex > 0) { histIndex--; go(history[histIndex], false) } }
    function forward() { if (histIndex < history.length - 1) { histIndex++; go(history[histIndex], false) } }

    function updateBlur() {
        Sys.setBlur(win, 0, 0, sidebar.width + winRadius, win.height, winRadius)
    }
    onWidthChanged: Qt.callLater(updateBlur)
    onHeightChanged: Qt.callLater(updateBlur)
    onActiveChanged: if (active) Theme.refresh()
    // el modo claro/oscuro puede cambiar con la ventana abierta
    Timer { id: themeWatch; interval: 1500; running: true; repeat: true; onTriggered: Theme.refresh() }

    Component.onCompleted: {
        Theme.refresh()
        go(startPage && (pageFiles[startPage] || startPage.indexOf("kde:") === 0) ? startPage : "apariencia")
        Qt.callLater(updateBlur)
    }

    // Fondo de la ventana con un hueco donde va la barra lateral translúcida
    Canvas {
        id: bg
        anchors.fill: parent
        property color fill: Theme.windowBg
        onFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        function rr(c, x, y, w, h, r) {
            c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r)
            c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath()
        }
        onPaint: {
            const c = getContext("2d"); c.reset()
            c.fillStyle = fill
            rr(c, 0, 0, width, height, win.winRadius); c.fill()
            c.globalCompositeOperation = "destination-out"
            c.fillRect(0, 0, sidebar.width, height)
        }
    }

    // ── Barra lateral flotante ─────────────────────────────────────────────
    Rectangle {
        id: sidebar
        width: win.sidebarWidth
        height: win.height
        color: "transparent"
        clip: true
        // Fondo translúcido con las esquinas izquierdas de la ventana redondeadas
        Rectangle {
            anchors.fill: parent; anchors.rightMargin: -win.winRadius
            radius: win.winRadius
            color: Theme.sidebarBg
        }
        Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: Theme.sidebarEdge }

        DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }

        TrafficLights { id: lights; x: 20; y: 19 }

        Rectangle {
            id: searchBox
            x: 10; y: 50
            width: parent.width - 20; height: 26
            radius: 7
            color: Theme.search
            Magnifier { x: 9; anchors.verticalCenter: parent.verticalCenter; size: 12 }
            TextInput {
                id: search
                x: 30; width: parent.width - 40
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font; font.pixelSize: Theme.fontSize
                color: Theme.text
                selectionColor: Theme.accent
                clip: true
                Txt { visible: !search.text && !search.activeFocus; text: "Buscar"; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        QQC.ScrollView {
            id: sbScroll
            anchors { top: searchBox.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
            clip: true
            contentWidth: availableWidth
            QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff
            Column {
                width: sbScroll.availableWidth
                // Cuenta del usuario
                Item {
                    width: parent.width; height: 52
                    visible: search.text === ""
                    Rectangle {
                        id: avatar
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32; radius: 16
                        color: Theme.tile.grey
                        clip: true
                        Image { anchors.fill: parent; source: Sys.exists(Sys.home() + "/.face.icon") ? "file://" + Sys.home() + "/.face.icon" : ""; fillMode: Image.PreserveAspectCrop }
                        Txt { anchors.centerIn: parent; text: userName.charAt(0).toUpperCase(); color: "white"; font.pixelSize: 15; font.bold: true; visible: !Sys.exists(Sys.home() + "/.face.icon") }
                    }
                    Column {
                        anchors.left: avatar.right; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter
                        Txt { text: userName; font.weight: Font.DemiBold }
                        Txt { text: "Cuenta local"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
                    }
                    MouseArea { anchors.fill: parent; onClicked: win.go("usuarios") }
                }
                Repeater {
                    model: win.sections
                    delegate: Loader {
                        width: parent.width
                        readonly property var s: modelData
                        readonly property bool matches: s.sep ? search.text === "" :
                            (search.text === "" || (s.title + " " + s.keys).toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
                        visible: matches
                        height: matches ? (s.sep ? 10 : 28) : 0
                        sourceComponent: s.sep ? sepComp : itemComp
                    }
                }
            }
        }
    }
    readonly property string userName: {
        const g = Sys.run("getent", ["passwd", Sys.user()]).split(":")
        const n = (g[4] || "").split(",")[0]
        return n || Sys.user()
    }
    Component { id: sepComp; Item {} }
    Component {
        id: itemComp
        Item {
            readonly property bool sel: win.section === parent.s.id
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                radius: 6
                color: sel ? Theme.selection : "transparent"
            }
            Tile {
                id: t
                x: 18; anchors.verticalCenter: parent.verticalCenter
                size: 20
                icon: parent.parent.s.icon || ""
                glyph: parent.parent.s.glyph || ""
                base: Theme.tile[parent.parent.s.color]
            }
            Txt {
                anchors.left: t.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.s.title
                color: sel ? "white" : Theme.text
            }
            MouseArea { anchors.fill: parent; onClicked: win.go(parent.parent.s.id) }
        }
    }

    // ── Contenido ─────────────────────────────────────────────────────────
    Item {
        id: content
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        // Sequoia: la sombra del contenido sobre la barra lateral es una línea; sin cápsula en las flechas

        Item {
            id: header
            width: parent.width; height: 54
            DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
            NavArrows {
                id: nav
                x: 18; anchors.verticalCenter: parent.verticalCenter
                canBack: win.histIndex > 0
                canForward: win.histIndex < win.history.length - 1
                onBackClicked: win.back()
                onForwardClicked: win.forward()
            }
            Txt {
                anchors.left: nav.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: loader.item ? loader.item.title : ""
                font.pixelSize: 15; font.weight: Font.DemiBold
            }
        }
        Loader {
            id: loader
            anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
            onLoaded: { win.currentTitle = item.title; if (item.open) item.open.connect(win.go) }
        }
    }
}
