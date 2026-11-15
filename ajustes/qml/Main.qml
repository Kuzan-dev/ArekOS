import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC
import Qt5Compat.GraphicalEffects as GE

Window {
    id: win
    width: 790
    height: 650
    minimumWidth: 660
    minimumHeight: 440
    visible: true
    title: currentTitle
    color: "transparent"

    // Tahoe: la barra lateral es un panel de cristal flotante dentro de la ventana, a 8 px de los bordes
    // maximizada o a pantalla completa, las esquinas de la ventana son rectas (la barra lateral sigue flotando)
    readonly property bool llena: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int winRadius: llena ? 0 : 20
    readonly property int sidebarWidth: 220
    readonly property int sbMargin: 8
    readonly property int sbRadius: 14

    // Secciones (id, título, icono, color, palabras clave para buscar y la frase de su cabecera)
    readonly property var sections: [
        { id: "wifi", title: "Wi‑Fi", icon: "network-wireless-symbolic", color: "blue", keys: "wifi red inalámbrica", desc: "Conéctate a redes Wi‑Fi y administra las redes que conoces." },
        { id: "bluetooth", title: "Bluetooth", icon: "network-bluetooth-symbolic", color: "blue", keys: "dispositivos", desc: "Conecta y administra auriculares, teclados, ratones y otros dispositivos Bluetooth." },
        { id: "red", title: "Red", icon: "map-globe-symbolic", color: "blue", keys: "ethernet ip cable", desc: "Configura la conexión por cable, las direcciones IP y el resto de ajustes de red." },
        { id: "vpn", title: "VPN", icon: "network-vpn-symbolic", color: "blue", keys: "wireguard", desc: "Añade y administra conexiones VPN, como WireGuard u OpenVPN." },
        { id: "energia", title: "Energía", icon: "battery-full-symbolic", color: "green", keys: "batería suspender reposo rendimiento", desc: "Elige el modo de energía y cuándo se atenúa o se apaga la pantalla." },
        { sep: true },
        { id: "general", title: "General", icon: "preferences-system-symbolic", color: "grey", keys: "información fecha hora idioma inicio almacenamiento actualización", desc: "Administra la información del equipo, las actualizaciones, el idioma, la fecha y hora y más." },
        { id: "accesibilidad", title: "Accesibilidad", icon: "preferences-desktop-accessibility-symbolic", color: "blue", keys: "zoom contraste", desc: "Adapta el escritorio a tu vista y a tu forma de usar el puntero." },
        { id: "apariencia", title: "Apariencia", icon: "color-mode-black-white-symbolic", color: "black", keys: "oscuro claro tema color acento", desc: "Elige el modo claro u oscuro, el color de acento y el estilo de los menús." },
        { id: "barra", title: "Barra de menús", icon: "application-menu-symbolic", color: "grey", keys: "reloj panel superior", desc: "Elige qué se muestra en la barra de menús y cómo se ve." },
        { id: "dock", title: "Escritorio y Dock", icon: "view-app-grid-symbolic", color: "black", keys: "dock minimizar ventanas", desc: "Configura el Dock, el Launchpad, las ventanas y Mission Control." },
        { id: "pantallas", title: "Pantallas", icon: "monitor-symbolic", color: "blue", keys: "resolución escala monitor hdr luz nocturna", desc: "Ajusta el brillo, la resolución, la escala y la luz nocturna de tus pantallas." },
        { id: "spotlight", title: "Spotlight", icon: "search-symbolic", color: "blue", keys: "krunner buscar", desc: "Elige qué resultados muestra Spotlight y cómo se abre." },
        { id: "fondo", title: "Fondo de pantalla", glyph: "✿", color: "teal", keys: "wallpaper imagen", desc: "Elige la imagen del escritorio de cada pantalla." },
        { sep: true },
        { id: "notificaciones", title: "Notificaciones", icon: "notifications-symbolic", color: "red", keys: "avisos", desc: "Elige dónde y durante cuánto tiempo aparecen las notificaciones de cada app." },
        { id: "sonido", title: "Sonido", icon: "audio-volume-high-symbolic", color: "pink", keys: "volumen altavoces micrófono", desc: "Ajusta el volumen, los efectos de sonido, los altavoces y el micrófono." },
        { id: "concentracion", title: "Concentración", glyph: "☾", color: "indigo", keys: "no molestar", desc: "Silencia las notificaciones con No molestar y elige cuándo se activa solo." },
        { sep: true },
        { id: "bloqueo", title: "Pantalla de bloqueo", icon: "system-lock-screen-symbolic", color: "black", keys: "contraseña bloquear", desc: "Elige cuándo se bloquea la pantalla y cómo se ve el inicio de sesión." },
        { id: "privacidad", title: "Privacidad y seguridad", icon: "security-high-symbolic", color: "blue", keys: "permisos", desc: "Revisa los permisos de las apps y la seguridad del sistema." },
        { id: "usuarios", title: "Usuarios y grupos", icon: "system-users-symbolic", color: "blue", keys: "cuentas", desc: "Administra las cuentas de usuario y sus permisos." },
        { id: "contrasenas", title: "Contraseñas", icon: "password-copy-symbolic", color: "grey", keys: "kwallet llavero", desc: "Administra las contraseñas guardadas en el llavero de KDE." },
        { sep: true },
        { id: "teclado", title: "Teclado", icon: "input-keyboard-symbolic", color: "grey", keys: "atajos distribución", desc: "Ajusta la repetición de teclas y los atajos de teclado." },
        { id: "raton", title: "Ratón y trackpad", icon: "input-mouse-symbolic", color: "grey", keys: "puntero trackpad desplazamiento natural clic", desc: "Ajusta la velocidad del puntero, el desplazamiento y los clics del ratón y el trackpad." },
        { id: "impresoras", title: "Impresoras y escáneres", icon: "printer-symbolic", color: "grey", keys: "imprimir", desc: "Añade y administra impresoras y escáneres." }
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
        // cabecera de Tahoe (icono grande, título y descripción) solo en las secciones de la barra lateral
        const s = kde ? null : sectionById(id)
        loader.setSource(kde ? "PageKde.qml" : pageFiles[id] + ".qml", s && s.desc ? {
            pageId: id, heroIcon: s.icon || "", heroGlyph: s.glyph || "", heroColor: Theme.tile[s.color], heroDesc: s.desc
        } : { pageId: id })
    }
    function back() { if (histIndex > 0) { histIndex--; go(history[histIndex], false) } }
    function forward() { if (histIndex < history.length - 1) { histIndex++; go(history[histIndex], false) } }

    function updateBlur() {
        // la barra lateral opaca no necesita desenfoque
        if (Theme.translucida) Sys.setBlur(win, sidebar.x, sidebar.y, sidebar.width, sidebar.height, sbRadius)
        else Sys.clearBlur(win)
    }
    onWidthChanged: Qt.callLater(updateBlur)
    onHeightChanged: Qt.callLater(updateBlur)
    onActiveChanged: if (active) Theme.refresh()
    Connections { target: Theme; function onTranslucidaChanged() { win.updateBlur() } }
    // el modo claro/oscuro puede cambiar con la ventana abierta
    Timer { id: themeWatch; interval: 1500; running: true; repeat: true; onTriggered: Theme.refresh() }

    Component.onCompleted: {
        Theme.refresh()
        go(startPage && (pageFiles[startPage] || startPage.indexOf("kde:") === 0) ? startPage : "apariencia")
        Qt.callLater(updateBlur)
    }

    // Fondo de la ventana con un hueco redondeado donde va la barra lateral translúcida
    Canvas {
        id: bg
        anchors.fill: parent
        property color fill: Theme.windowBg
        readonly property int radio: win.winRadius
        onFillChanged: requestPaint()
        onRadioChanged: requestPaint()
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
            // 1 px por dentro del panel: el fondo queda bajo su filo y no se ve una rendija en la unión
            rr(c, sidebar.x + 1, sidebar.y + 1, sidebar.width - 2, sidebar.height - 2, win.sbRadius - 1); c.fill()
        }
    }

    // ── Barra lateral flotante ─────────────────────────────────────────────
    Rectangle {
        id: sidebar
        x: win.sbMargin; y: win.sbMargin
        width: win.sidebarWidth
        height: win.height - 2 * win.sbMargin
        radius: win.sbRadius
        color: Theme.sidebarBg
        border.width: 1; border.color: Theme.sidebarRim
        clip: true

        DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }

        TrafficLights { id: lights; x: 14; y: 14 }

        // buscador en píldora, como en Tahoe
        Rectangle {
            id: searchBox
            x: 10; y: 40
            width: parent.width - 20; height: 30
            radius: height / 2
            color: Theme.search
            Magnifier { x: 12; anchors.verticalCenter: parent.verticalCenter; size: 12 }
            TextInput {
                id: search
                x: 32; width: parent.width - 44
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
                        // foto en círculo, como en macOS (clip recorta por el rectángulo, no por el radio)
                        Image { id: faceImg; anchors.fill: parent; visible: false; source: Sys.exists(Sys.home() + "/.face.icon") ? "file://" + Sys.home() + "/.face.icon?v=" + Sys.faceRevision : ""; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize.width: 96 }
                        Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; antialiasing: true }
                        GE.OpacityMask { anchors.fill: parent; source: faceImg; maskSource: faceMask; visible: faceImg.status === Image.Ready }
                        Txt { anchors.centerIn: parent; text: userName.charAt(0).toUpperCase(); color: "white"; font.pixelSize: 15; font.bold: true; visible: faceImg.status !== Image.Ready }
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
                        height: matches ? (s.sep ? 10 : 30) : 0
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
                anchors.leftMargin: 8; anchors.rightMargin: 8
                radius: 9
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
        anchors { left: sidebar.right; leftMargin: 4; right: parent.right; top: parent.top; bottom: parent.bottom }
        // Tahoe: las flechas van en una píldora; el título solo en las páginas sin cabecera (subpáginas y KDE)

        Item {
            id: header
            width: parent.width; height: 54
            DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
            NavPill {
                id: nav
                x: 14; anchors.verticalCenter: parent.verticalCenter
                canBack: win.histIndex > 0
                canForward: win.histIndex < win.history.length - 1
                onBackClicked: win.back()
                onForwardClicked: win.forward()
            }
            Txt {
                anchors.left: nav.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                visible: !(loader.item && loader.item.heroDesc)
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
