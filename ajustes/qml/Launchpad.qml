import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami

// Launchpad: cuadrícula de apps a pantalla completa (medidas de macOS a 1080p).
Window {
    id: lp
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "vitrum-launchpad"
    LayerShell.Window.scope: "launchpad"
    // KWin la abre en la pantalla activa (la del puntero) al mostrarla, como macOS
    LayerShell.Window.wantsToBeOnActiveScreen: true
    // misma capa que el dock: el Shell vuelve a mostrar el dock después para que quede encima, como en macOS
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    readonly property real s: height / 1080          // escala respecto a 1080p
    readonly property int cols: 7
    readonly property int rows: 5
    readonly property int perPage: cols * rows
    property var allApps: []
    // Carpetas automáticas por categoría (vitrumrc [Launchpad] Carpetas): las apps del dock quedan sueltas al
    // principio, las demás van a la carpeta de su primera categoría reconocida; una carpeta con una sola app no
    // se crea (la app queda suelta). Al buscar se muestran todas las apps sin carpetas.
    property bool useFolders: true
    property var grouped: []
    readonly property var folderDefs: [
        // Juegos primero: Steam y otros también se declaran «Network»
        { name: "Juegos", cats: ["Game"] },
        { name: "Internet", cats: ["Network", "WebBrowser", "Email", "Chat"] },
        { name: "Oficina", cats: ["Office", "WordProcessor", "Spreadsheet", "Presentation"] },
        { name: "Multimedia", cats: ["AudioVideo", "Audio", "Video", "Player", "Music"] },
        { name: "Gráficos", cats: ["Graphics", "Photography", "Viewer"] },
        { name: "Desarrollo", cats: ["Development", "IDE", "TextEditor"] },
        { name: "Educación", cats: ["Education", "Science"] },
        { name: "Sistema", cats: ["Settings", "System", "Monitor", "PackageManager", "FileManager", "TerminalEmulator"] },
        { name: "Utilidades", cats: ["Utility", "Accessibility"] }
    ]
    function group(all) {
        const pinned = Sys.readConf("vitrumrc", ["Dock"], "Launchers", "").split(",")
            .filter(x => x.startsWith("applications:")).map(x => x.slice(13))
        const loose = [], buckets = folderDefs.map(() => []), other = []
        for (const id of pinned) { const a = all.find(x => x.id === id); if (a) loose.push(a) }
        for (const a of all) {
            if (pinned.indexOf(a.id) >= 0) continue
            const cats = (a.categories || "").split(";")
            const f = folderDefs.findIndex(d => d.cats.some(c => cats.indexOf(c) >= 0))
            if (f >= 0) buckets[f].push(a); else other.push(a)
        }
        const folders = [], singles = other
        buckets.forEach((b, i) => {
            if (b.length > 1) folders.push({ folder: true, name: folderDefs[i].name, apps: b, id: "folder:" + folderDefs[i].name })
            else singles.push(...b)
        })
        singles.sort((a, b) => a.name.localeCompare(b.name))
        return loose.concat(folders, singles)
    }
    readonly property var apps: {
        const q = search.text.trim().toLowerCase()
        if (!q) return useFolders ? grouped : allApps
        return allApps.filter(a => (a.name + " " + a.generic + " " + a.keywords).toLowerCase().indexOf(q) >= 0)
    }
    // carpeta abierta (panel sobre la cuadrícula) o null
    property var folder: null
    readonly property int pages: Math.max(1, Math.ceil(apps.length / perPage))
    property int page: 0
    property bool shown: false
    // Selección con el teclado (como en macOS): al escribir se marca el primer resultado; las flechas mueven
    // la selección por la cuadrícula (y cambian de página al pasar el borde) e Intro abre la app marcada.
    property int sel: -1
    function select(i) {
        if (!apps.length) { sel = -1; return }
        sel = Math.max(0, Math.min(apps.length - 1, i))
        page = Math.floor(sel / perPage)
    }
    function move(dx, dy) {
        if (sel < 0) { select(page * perPage); return }
        const inPage = sel % perPage, col = inPage % cols, row = Math.floor(inPage / cols)
        if (dx !== 0) {
            // a la derecha desde la última columna salta a la página siguiente (y al revés)
            if (dx > 0 && col === cols - 1) select((page + 1) * perPage + row * cols)
            else if (dx < 0 && col === 0) { if (page > 0) select((page - 1) * perPage + row * cols + cols - 1) }
            else select(sel + dx)
        } else {
            const t = sel + dy * cols
            if (t >= page * perPage && t < (page + 1) * perPage && t < apps.length) select(t)
            else if (dy > 0 && t >= apps.length && Math.floor((apps.length - 1) / perPage) === page) select(apps.length - 1)
        }
    }

    function toggle() { shown ? close2() : open2() }
    function open2() {
        allApps = Sys.apps()
        useFolders = Sys.readConf("vitrumrc", ["Launchpad"], "Carpetas", "true") !== "false"
        grouped = useFolders ? group(allApps) : []
        search.text = ""; page = 0; sel = -1; folder = null
        showFullScreen(); shown = true
        Qt.callLater(() => { updateBlur(); search.forceActiveFocus() })
    }
    function close2() { shown = false; folder = null; hideTimer.restart() }
    function updateBlur() { if (visible) Sys.setBlur(lp, 0, 0, width, height, 0) }
    onWidthChanged: Qt.callLater(updateBlur)
    onHeightChanged: Qt.callLater(updateBlur)
    function launch(a) {
        if (a.folder) { folder = a; return }
        Sys.launch(a.id); close2()
    }
    Timer { id: hideTimer; interval: 180; onTriggered: lp.hide() }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.30)
        opacity: lp.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 170 } }
    }
    Item {
        anchors.fill: parent
        opacity: lp.shown ? 1 : 0
        scale: lp.shown ? 1 : 1.08
        Behavior on opacity { NumberAnimation { duration: 170 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: lp.close2()
            onWheel: (w) => { if (w.angleDelta.y < 0 || w.angleDelta.x < 0) lp.page = Math.min(lp.pages - 1, lp.page + 1); else lp.page = Math.max(0, lp.page - 1) }
        }

        // Buscador
        Rectangle {
            id: field
            width: 250 * lp.s; height: 26 * lp.s; radius: 7 * lp.s
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30 * lp.s
            color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.20)
            Row {
                anchors.centerIn: search.text ? undefined : parent
                x: 10 * lp.s; anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * lp.s
                visible: !search.text
                Magnifier { size: 13 * lp.s; color: Qt.rgba(1, 1, 1, 0.80); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Buscar"; color: Qt.rgba(1, 1, 1, 0.45); font.family: Theme.font; font.pixelSize: 15 * lp.s; anchors.verticalCenter: parent.verticalCenter }
            }
            TextInput {
                id: search
                anchors.fill: parent; anchors.leftMargin: 10 * lp.s; anchors.rightMargin: 10 * lp.s
                verticalAlignment: TextInput.AlignVCenter
                color: "white"; selectionColor: Theme.accent
                font.family: Theme.font; font.pixelSize: 15 * lp.s
                onTextChanged: { lp.page = 0; lp.sel = text.trim() ? 0 : -1 }
                Keys.onEscapePressed: lp.folder ? lp.folder = null : text ? text = "" : lp.close2()
                Keys.onReturnPressed: if (!lp.folder && lp.apps.length) lp.launch(lp.apps[Math.max(0, lp.sel)])
                Keys.onEnterPressed: if (!lp.folder && lp.apps.length) lp.launch(lp.apps[Math.max(0, lp.sel)])
                // sin búsqueda ni selección, izquierda/derecha cambian de página; si hay selección, la mueven
                Keys.onRightPressed: (e) => { if (lp.sel < 0 && !text) lp.page = Math.min(lp.pages - 1, lp.page + 1); else if (lp.sel >= 0 || cursorPosition === text.length) lp.move(1, 0); else e.accepted = false }
                Keys.onLeftPressed: (e) => { if (lp.sel < 0 && !text) lp.page = Math.max(0, lp.page - 1); else if (lp.sel >= 0) lp.move(-1, 0); else e.accepted = false }
                Keys.onDownPressed: lp.move(0, 1)
                Keys.onUpPressed: lp.move(0, -1)
                Keys.onTabPressed: lp.move(1, 0)
                Keys.onBacktabPressed: lp.move(-1, 0)
            }
        }

        // Páginas de iconos
        Item {
            id: pagesArea
            anchors { top: field.bottom; topMargin: 30 * lp.s; left: parent.left; right: parent.right; bottom: dots.top; bottomMargin: 20 * lp.s }
            clip: true
            Row {
                x: -lp.page * pagesArea.width
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Repeater {
                    model: lp.pages
                    Item {
                        id: pg
                        required property int index
                        width: pagesArea.width; height: pagesArea.height
                        Grid {
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: lp.cols
                            Repeater {
                                model: lp.apps.slice(pg.index * lp.perPage, (pg.index + 1) * lp.perPage)
                                Item {
                                    required property var modelData
                                    required property int index
                                    readonly property bool selected: lp.sel === pg.index * lp.perPage + index
                                    width: 215 * lp.s; height: 174 * lp.s
                                    // resaltado de la selección: recuadro redondeado translúcido que abarca icono y nombre,
                                    // dentro de la celda (el área de páginas recorta lo que sobresale)
                                    Rectangle {
                                        visible: parent.selected
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 0
                                        width: parent.width - 6 * lp.s; height: 150 * lp.s; radius: 16 * lp.s
                                        color: Qt.rgba(1, 1, 1, 0.18)
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    Item {
                                        id: ic
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 110 * lp.s; height: width
                                        y: 8 * lp.s
                                        scale: ma.pressed ? 0.92 : 1
                                        Kirigami.Icon {
                                            anchors.fill: parent
                                            visible: !modelData.folder
                                            source: modelData.folder ? "" : (modelData.icon || "application-x-executable")
                                        }
                                        // carpeta: cuadrado translúcido con las primeras 9 apps en miniatura, como macOS
                                        Rectangle {
                                            visible: !!modelData.folder
                                            anchors.fill: parent; anchors.margins: 6 * lp.s
                                            radius: 24 * lp.s
                                            color: Qt.rgba(1, 1, 1, 0.20)
                                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
                                            Grid {
                                                anchors.centerIn: parent
                                                columns: 3; spacing: 6 * lp.s
                                                Repeater {
                                                    model: modelData.folder ? modelData.apps.slice(0, 9) : []
                                                    Kirigami.Icon {
                                                        required property var modelData
                                                        width: 24 * lp.s; height: width
                                                        source: modelData.icon || "application-x-executable"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.top: ic.bottom; anchors.topMargin: 1 * lp.s
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width - 24 * lp.s
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        color: "white"
                                        font.family: Theme.font; font.pixelSize: 12.5 * lp.s; font.weight: Font.Medium
                                        renderType: Text.NativeRendering
                                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
                                    }
                                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: lp.launch(modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Puntos de página
        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 120 * lp.s
            spacing: 10 * lp.s
            visible: lp.pages > 1
            Repeater {
                model: lp.pages
                Rectangle {
                    required property int index
                    width: 8 * lp.s; height: width; radius: width / 2
                    color: Qt.rgba(1, 1, 1, index === lp.page ? 0.95 : 0.35)
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: lp.page = index }
                }
            }
        }
    }

    // Carpeta abierta: panel translúcido centrado con su nombre encima; un clic fuera o Esc la cierra
    Item {
        anchors.fill: parent
        visible: opacity > 0
        opacity: lp.folder ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        readonly property var fapps: lp.folder ? lp.folder.apps : []
        readonly property int fcols: Math.min(5, Math.max(3, fapps.length))
        MouseArea { anchors.fill: parent; onClicked: lp.folder = null; onWheel: {} }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: fpanel.top; anchors.bottomMargin: 22 * lp.s
            text: lp.folder ? lp.folder.name : ""
            color: "white"
            font.family: Theme.font; font.pixelSize: 30 * lp.s; font.weight: Font.Medium
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Rectangle {
            id: fpanel
            anchors.centerIn: parent
            width: parent.fcols * 170 * lp.s + 50 * lp.s
            height: Math.min(Math.ceil(parent.fapps.length / parent.fcols), 3) * 160 * lp.s + 50 * lp.s
            radius: 36 * lp.s
            color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.20)
            scale: lp.folder ? 1 : 0.9
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }   // los clics dentro del panel no la cierran
            Flickable {
                anchors.fill: parent; anchors.margins: 25 * lp.s
                clip: true
                contentHeight: fgrid.height
                boundsBehavior: Flickable.StopAtBounds
                Grid {
                    id: fgrid
                    columns: fpanel.parent.fcols
                    Repeater {
                        model: fpanel.parent.fapps
                        Item {
                            required property var modelData
                            width: 170 * lp.s; height: 160 * lp.s
                            Kirigami.Icon {
                                id: fic
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 6 * lp.s
                                width: 100 * lp.s; height: width
                                source: modelData.icon || "application-x-executable"
                                scale: fma.pressed ? 0.92 : 1
                            }
                            Text {
                                anchors.top: fic.bottom; anchors.topMargin: 2 * lp.s
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 20 * lp.s
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.name
                                elide: Text.ElideRight
                                color: "white"
                                font.family: Theme.font; font.pixelSize: 12.5 * lp.s; font.weight: Font.Medium
                                renderType: Text.NativeRendering
                                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
                            }
                            MouseArea { id: fma; anchors.fill: parent; onClicked: lp.launch(modelData) }
                        }
                    }
                }
            }
        }
    }
}
