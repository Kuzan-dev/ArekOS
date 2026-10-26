import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import org.kde.layershell as LayerShell
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

// Dock de Vitrum (medidas del de macOS Monterey/Sequoia a 1x): abajo, a la izquierda o a la derecha,
// con ampliación, ocultación automática e indicadores, como en Ajustes → Escritorio y Dock de macOS.
Window {
    id: dock
    property int tile: 64
    property bool bounce: true
    property string position: "bottom"
    property bool autohide: false
    property bool magnify: false
    property int magSize: 96
    property bool indicators: true
    property bool hideOnMax: true
    // botones de cada ventana en la vista previa: "abajo" o "arriba" de la miniatura
    property string previewButtons: "abajo"
    // Material medido en macOS (ver tema-plasma/MATERIAL.md): desenfoque σ≈30 (fuerza 10 de KWin), saturación
    // y contraste del efecto de contraste de KWin, y una capa negra (oscuro) o blanca (claro) que fija brillo y gris.
    // Se puede recalibrar en vitrumrc [Material].
    QtObject {
        id: mat
        readonly property bool d: Theme.dark
        property real tint: Number(Sys.readConf("vitrumrc", ["Material"], d ? "DockTintDark" : "DockTintLight", d ? "0.26" : "0.36"))
        property real contrast: Number(Sys.readConf("vitrumrc", ["Material"], d ? "ContrastDark" : "ContrastLight", d ? "0.813" : "0.972"))
        // tinte en la intensidad del efecto (ver Material.qml): lo aplica el desenfoque en el espacio de macOS
        property real intensity: Material.fx ? 10 * Math.round(dock.radius) + (d ? 1 - tint : 1 + tint) : 1.0
        onIntensityChanged: dock.updateRegions()
        property real saturation: Number(Sys.readConf("vitrumrc", ["Material"], d ? "SaturationDark" : "SaturationLight", d ? "1.54" : "1.74"))
        onContrastChanged: dock.updateRegions()
        onSaturationChanged: dock.updateRegions()
    }
    // se relee periódicamente (Shell.qml) para aplicar en vivo lo que se cambie en Ajustes
    function reload() {
        const c = (k, d) => Sys.readConf("vitrumrc", ["Dock"], k, d)
        tile = Math.max(40, Math.min(96, Number(c("TileSize", "64"))))
        bounce = c("Bounce", "true") === "true"
        const pos = c("Position", "bottom")
        position = ["bottom", "left", "right"].indexOf(pos) >= 0 ? pos : "bottom"
        autohide = c("Autohide", "false") === "true"
        magnify = c("Magnification", "false") === "true"
        magSize = Math.max(tile, Math.min(128, Number(c("MagnificationSize", "96"))))
        indicators = c("ShowIndicators", "true") === "true"
        hideOnMax = c("HideOnMaximize", "true") === "true"
        previewButtons = c("PreviewButtons", "abajo") === "arriba" ? "arriba" : "abajo"
    }
    readonly property bool vertical: position !== "bottom"
    readonly property int iconSize: Math.round(tile * 0.9)
    readonly property int barH: tile + 15            // 79 px con casillas de 64
    readonly property int gap: 5
    // sitio para la etiqueta, el rebote y la ampliación (hacia dentro de la pantalla)
    readonly property int headroom: Math.max(64, (magnify ? magSize - tile : 0) + 44)
    readonly property int thick: barH + gap + headroom
    // macOS: esquinas de 19 px con una barra de 79 (casillas de 64)
    readonly property int radius: Math.round(barH * 0.24)
    property var pinned: Sys.readConf("vitrumrc", ["Dock"], "Launchers",
        "applications:org.kde.dolphin.desktop,vitrum:launchpad,applications:org.mozilla.firefox.desktop,applications:org.kde.discover.desktop,applications:org.kde.konsole.desktop,applications:org.kde.kwrite.desktop,applications:org.vitrum.ajustes.desktop").split(",").filter(x => x)
    property string hoverName: ""
    // Vista previa de ventanas: aparece tras dejar el puntero 0,6 s sobre una app abierta
    property string hoverApp: ""
    property bool hoverHasWindows: false
    DockPreview { id: preview; dock: dock; screen: dock.screen }
    Timer {
        id: previewTimer; interval: 600
        onTriggered: if (dock.hoverApp && dock.hoverHasWindows) dock.showPreview(dock.hoverApp)
    }
    // vista previa de una app sobre el último icono señalado (dock.hoverPos, en coordenadas del dock)
    function showPreview(app) {
        const off = dock.position === "bottom" ? Qt.point(0, (dock.screen ? dock.screen.height : dock.height) - dock.height)
                  : dock.position === "right" ? Qt.point((dock.screen ? dock.screen.width : dock.width) - dock.width, 0) : Qt.point(0, 0)
        preview.show(app, Qt.point(dock.hoverPos.x + off.x, dock.hoverPos.y + off.y))
        dock.hoverName = ""      // la vista previa ya muestra los títulos
    }
    function debugPreview(app) { preview.show(app, Qt.point((screen ? screen.width : width) / 2, (screen ? screen.height : height) - thick + headroom)) }
    Timer { id: previewHide; interval: 350; onTriggered: if (!preview.hovered && !dock.hoverApp) preview.hide2() }
    onHoverAppChanged: {
        if (hoverApp && hoverHasWindows) { if (preview.visible) previewTimer.interval = 80; else previewTimer.interval = 600; previewTimer.restart() }
        else { previewTimer.stop(); previewHide.restart() }
    }
    Connections { target: preview; function onHoveredChanged() { if (!preview.hovered) previewHide.restart() } }
    property point hoverPos: Qt.point(0, 0)          // punto del icono más cercano al centro de la pantalla
    property bool trashFull: Sys.trashFull()

    // Ocultación automática: visible mientras el ratón esté encima (o haya un menú abierto)
    readonly property bool hovering: hover.hovered
    // También se aparta de una ventana maximizada o a pantalla completa en su pantalla (y escritorio)
    readonly property bool covered: hideOnMax && coverCount > 0
    property int coverCount: 0
    readonly property bool revealed: !(autohide || covered) || hovering || dockMenu.visible || holdTimer.running
    TaskManager.TasksModel {
        id: winTasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: true
        screenGeometry: dock.screen ? Qt.rect(dock.screen.virtualX, dock.screen.virtualY, dock.screen.width, dock.screen.height) : Qt.rect(0, 0, 0, 0)
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true
        filterNotMinimized: false
    }
    Instantiator {
        model: winTasks
        delegate: QtObject {
            required property var model
            // se aparta de cualquier ventana que invada su zona (maximizada, en mosaico o simplemente grande),
            // como «Esquivar ventanas» de KDE; la zona es fija, así que ocultarse no cambia el resultado
            readonly property rect geo: model.Geometry || Qt.rect(0, 0, 0, 0)
            readonly property bool covers: model.IsWindow === true && model.IsMinimized !== true
                && (model.IsFullScreen === true || model.IsMaximized === true || dock.intersectsZone(geo, dock.zoneVersion))
            onCoversChanged: dock.recountCover()
            Component.onDestruction: Qt.callLater(dock.recountCover)
        }
        onObjectAdded: Qt.callLater(dock.recountCover)
        onObjectRemoved: Qt.callLater(dock.recountCover)
        id: coverInst
    }
    // zona del dock en coordenadas globales (lógicas), sin ampliación ni desplazamiento de ocultar
    property int zoneVersion: 0
    onWidthChanged: zoneVersion++
    onHeightChanged: zoneVersion++
    function intersectsZone(g, _v) {
        if (!screen || g.width <= 0) return false
        const sx = screen.virtualX, sy = screen.virtualY, sw = screen.width, sh = screen.height
        const len = vertical ? bg.height : bg.width
        let z
        if (position === "bottom") z = Qt.rect(sx + (sw - len) / 2, sy + sh - gap - barH, len, barH + gap)
        else if (position === "left") z = Qt.rect(sx, sy + (sh - len) / 2, barH + gap, len)
        else z = Qt.rect(sx + sw - gap - barH, sy + (sh - len) / 2, barH + gap, len)
        return g.x < z.x + z.width && g.x + g.width > z.x && g.y < z.y + z.height && g.y + g.height > z.y
    }
    function recountCover() {
        let n = 0
        for (let i = 0; i < coverInst.count; ++i) { const o = coverInst.objectAt(i); if (o && o.covers) n++ }
        coverCount = n
    }
    Timer { id: holdTimer; interval: 450 }
    onHoveringChanged: {
        if (!hovering) holdTimer.restart()
        // ampliación: se fijan las posiciones sin ampliar antes de que cambien los tamaños
        if (hovering && magnify) { baseLen = vertical ? row.height : row.width; Qt.callLater(() => { magActive = hovering; trackPointer(hover.point.position) }) }
        if (!hovering) magActive = false     // el puntero se conserva mientras la ampliación se recoge
    }
    property bool magActive: false
    // entrada y salida suaves de la ampliación, como en macOS (~0,16 s)
    property real magAmount: magActive ? 1 : 0
    Behavior on magAmount { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    property real baseLen: 0
    // posición del ratón a lo largo del dock, en coordenadas de la fila sin ampliar. Se asigna en cada
    // movimiento (no es un enlace): depender del ancho de la fila, que cambia con la ampliación, creaba un bucle
    property real pointer: -1e6
    function trackPointer(p) {
        if (!magActive) return
        const winCenter = (vertical ? height : width) / 2
        pointer = baseLen / 2 + (vertical ? p.y : p.x) - winCenter
    }
    // perfil medido en macOS (captura con el puntero sobre Finder: 68, 66, 62, 56, 52 px): coseno que se
    // anula a unos 5,6 casillas del puntero
    function sizeAt(baseCenter) {
        if (magAmount <= 0) return tile
        const d = Math.abs(pointer - baseCenter), range = tile * 5.6
        return d >= range ? tile : tile + (magSize - tile) * magAmount * (Math.cos(Math.PI * d / range) + 1) / 2
    }
    onRevealedChanged: updateRegions()

    width: vertical ? thick : (screen ? screen.width : 1920)
    height: vertical ? (screen ? screen.height : 1080) : thick
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    title: "vitrum-dock#r" + dock.radius   // el radio lo usa el desenfoque de Vitrum (esquinas suavizadas)
    LayerShell.Window.scope: "dock"
    // con el Launchpad abierto el dock sube a la capa superior para quedar encima, como en macOS
    property bool overLaunchpad: false
    onOverLaunchpadChanged: remap()      // la capa solo se aplica al volver a mapear la superficie
    LayerShell.Window.layer: overLaunchpad ? LayerShell.Window.LayerOverlay : LayerShell.Window.LayerTop
    LayerShell.Window.anchors: position === "left" ? (LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom)
                             : position === "right" ? (LayerShell.Window.AnchorRight | LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom)
                             : (LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight)
    // con "apartarse de las ventanas maximizadas" no reserva espacio: la ventana maximizada ocupa toda la pantalla
    LayerShell.Window.exclusionZone: autohide || hideOnMax ? 0 : barH + gap
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Clic en el icono de una app: la trae al frente (su última ventana usada, restaurada si estaba minimizada).
    // Con la app ya delante y varias ventanas, cada clic trae la anterior en el orden de uso (y vuelve a empezar
    // tras la más antigua). El orden se fija al empezar la ronda: si se recalculara, solo alternaría entre dos.
    // Para elegir otra ventana, o cerrarla, minimizarla o maximizarla, está la vista previa (pasar el puntero).
    property string cycleApp: ""
    property var cycleIds: []        // ids de ventana (WinIdList[0]) de la más a la menos reciente
    property int cyclePos: 0
    function clickApp(index, model, item) {
        const i = tasks.makeModelIndex(index)
        if (model.IsLauncher && !model.IsWindow) { tasks.requestNewInstance(i); return }
        preview.hide2()
        if (model.IsGroupParent !== true) { tasks.requestActivate(i); cycleApp = ""; return }
        const R = TaskManager.AbstractTasksModel
        const wins = []
        for (let k = 0; k < tasks.rowCount(i); ++k) {
            const ix = tasks.makeModelIndex(index, k)
            const ids = tasks.data(ix, R.WinIdList)
            const t = tasks.data(ix, R.LastActivated)
            wins.push({ ix: ix, id: ids && ids.length ? String(ids[0]) : String(k), t: t ? new Date(t).getTime() : 0,
                        active: tasks.data(ix, R.IsActive) === true })
        }
        const app = String(model.AppId || "")
        const sameSet = cycleApp === app && cycleIds.length === wins.length && wins.every(w => cycleIds.indexOf(w.id) >= 0)
        if (model.IsActive === true && sameSet) {
            // siguiente de la ronda (si el usuario cambió de ventana por su cuenta, se sigue desde la que está activa)
            const cur = wins.find(w => w.active)
            const at = cur ? cycleIds.indexOf(cur.id) : cyclePos
            cyclePos = ((at >= 0 ? at : cyclePos) + 1) % cycleIds.length
        } else {
            // nueva ronda: orden de uso de este momento
            wins.sort((x, y) => y.t - x.t)
            cycleApp = app
            cycleIds = wins.map(w => w.id)
            // si la app ya estaba delante, su ventana activa es la primera: el clic trae la anterior
            cyclePos = model.IsActive === true && wins.length > 1 ? 1 : 0
        }
        const target = wins.find(w => w.id === cycleIds[cyclePos]) || wins[0]
        tasks.requestActivate(target.ix)
    }

    // Cambiar de pantalla (o de borde) una superficie layer-shell exige volver a crearla (ocultar y mostrar)
    function remap() { visible = false; remapTimer.restart() }
    Timer { id: remapTimer; interval: 40; onTriggered: { dock.visible = true; dock.updateRegions() } }
    // Al bloquear, el monitor entra en reposo y su salida desaparece unos segundos: el compositor cierra la
    // superficie y el dock queda oculto aunque la pantalla vuelva con el mismo nombre. Se vuelve a mostrar en
    // cuanto hay otra vez una pantalla real (la provisional de Qt no tiene nombre).
    Timer {
        interval: 1000; repeat: true
        running: !dock.visible && !remapTimer.running
        onTriggered: if (dock.screen && dock.screen.name !== "") { dock.visible = true; dock.updateRegions() }
    }
    function moveTo(s) {
        if (screen && screen.name === s.name) return
        visible = false
        screen = s
        visible = true
        updateRegions()
    }
    onPositionChanged: Qt.callLater(remap)
    function save(list) { pinned = list; Sys.writeConf("vitrumrc", ["Dock"], "Launchers", list.join(",")) }
    // "file:///usr/share/applications/x.desktop" → "applications:x.desktop"
    function launcherId(url) {
        const u = String(url || "")
        return u.indexOf("file://") === 0 && u.indexOf("/applications/") > 0 ? "applications:" + u.split("/").pop() : u
    }
    // se recalcula con un pequeño retraso, cuando los iconos ya se han recolocado
    Timer { id: regionTimer; interval: 60; onTriggered: dock.applyRegions() }
    function updateRegions() { regionTimer.restart() }
    function applyRegions() {
        // desplazamiento de la animación de ocultar: el desenfoque se mueve con el dock, fotograma a fotograma
        const off = content.hideOffset
        const dx = position === "left" ? -off : position === "right" ? off : 0
        const dy = position === "bottom" ? off : 0
        if (!revealed && off >= barH) {
            // oculto del todo: solo una franja de 2 px en el borde para volver a mostrarlo
            if (position === "bottom") Sys.setInputRegion(dock, bg.x, height - 2, bg.width, 2)
            else if (position === "left") Sys.setInputRegion(dock, 0, bg.y, 2, bg.height)
            else Sys.setInputRegion(dock, width - 2, bg.y, 2, bg.height)
            Sys.clearBlur(dock)
            return
        }
        // el fondo más lo que sobresalgan los iconos ampliados
        const x1 = Math.min(bg.x, row.x), y1 = Math.min(bg.y, row.y)
        const x2 = Math.max(bg.x + bg.width, row.x + row.width), y2 = Math.max(bg.y + bg.height, row.y + row.height)
        if (revealed) Sys.setInputRegion(dock, x1, y1, x2 - x1, y2 - y1)
        // misma forma que el fondo: el filo y el contorno quedan sobre el material, como en macOS
        Sys.setBlur(dock, bg.x + dx, bg.y + dy, bg.width, bg.height, dock.radius, mat.contrast, mat.intensity, mat.saturation)
    }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        filterByScreen: false
        filterByVirtualDesktop: false
        filterByActivity: false
        launcherList: dock.pinned.filter(x => x.indexOf("applications:") === 0)
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: dock.trashFull = Sys.trashFull() }

    Item {
        id: content
        anchors.fill: parent
        HoverHandler { id: hover; onPointChanged: dock.trackPointer(point.position) }

        // desplazamiento al ocultarse: hacia fuera de la pantalla
        property real hideOffset: dock.revealed ? 0 : dock.barH + dock.gap + 6
        Behavior on hideOffset { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        onHideOffsetChanged: dock.applyRegions()
        transform: Translate {
            x: dock.position === "left" ? -content.hideOffset : dock.position === "right" ? content.hideOffset : 0
            y: dock.position === "bottom" ? content.hideOffset : 0
        }

        // Sombra de macOS: negro al 24 %, σ = 19 px, sin desplazamiento (imagen de 9 partes, sin coste al
        // cambiar de tamaño; herramientas/sombra-dock.py)
        BorderImage {
            anchors.fill: bg
            anchors.margins: -60
            border { left: 79; top: 79; right: 79; bottom: 79 }
            source: "sombra-dock.png"
            smooth: true
        }
        // Fondo del dock: capa del material (el desenfoque lo pone KWin detrás, con la misma forma)
        Rectangle {
            id: bg
            x: dock.position === "left" ? dock.gap : dock.position === "right" ? dock.width - dock.gap - width : Math.round((dock.width - width) / 2)
            y: dock.position === "bottom" ? dock.height - dock.gap - height : Math.round((dock.height - height) / 2)
            // macOS: el dibujo del primer icono queda a 10 px del borde de la barra
            width: dock.vertical ? dock.barH : row.width + 4
            height: dock.vertical ? row.height + 4 : dock.barH
            radius: dock.radius
            color: "transparent"
            // material, contorno y filo medidos en macOS (con el mismo fondo en las dos pantallas):
            // contorno negro al 25,6 % (oscuro) / 7 % (claro), filo blanco al 15 %, con cobertura exacta por píxel
            MaterialEdge {
                anchors.fill: parent
                radius: dock.radius
                fill: Material.fx ? "transparent" : Theme.dark ? Qt.rgba(0, 0, 0, mat.tint) : Qt.rgba(1, 1, 1, mat.tint)
                outline: Qt.rgba(0, 0, 0, Theme.dark ? 0.28 : 0.08)
                highlight: Material.highlight
            }
            // la región de desenfoque sigue al fondo en el mismo fotograma (antes iba con retraso y se
            // veían el marco y el contenido moverse por separado)
            onWidthChanged: dock.applyRegions()
            onHeightChanged: dock.applyRegions()
            onXChanged: dock.applyRegions()
            onYChanged: dock.applyRegions()
        }

        // Iconos: la fila (o columna) apoya en el borde de la pantalla y crece hacia dentro al ampliarse
        Grid {
            id: row
            objectName: "dockRow"
            columns: dock.vertical ? 1 : 1000
            spacing: 0
            verticalItemAlignment: Grid.AlignBottom
            horizontalItemAlignment: dock.position === "right" ? Grid.AlignRight : Grid.AlignLeft
            x: dock.position === "left" ? bg.x + (dock.barH - dock.tile) / 2
             : dock.position === "right" ? bg.x + bg.width - (dock.barH - dock.tile) / 2 - width
             : Math.round((dock.width - width) / 2)
            // los iconos quedan 2,5 px por encima del centro de la barra (sitio para el punto de app abierta)
            y: dock.position === "bottom" ? bg.y + bg.height - (dock.barH - dock.tile) / 2 - height - 2.5 * dock.tile / 64
             : Math.round((dock.height - height) / 2)
            onWidthChanged: Qt.callLater(dock.updateRegions)
            onHeightChanged: Qt.callLater(dock.updateRegions)

            // Lanzadores y apps abiertas; Launchpad va detrás de la primera (Finder), como en macOS
            Repeater {
                model: tasks
                delegate: Grid {
                    required property var model
                    required property int index
                    columns: dock.vertical ? 1 : 2
                    verticalItemAlignment: Grid.AlignBottom
                    horizontalItemAlignment: dock.position === "right" ? Grid.AlignRight : Grid.AlignLeft
                    // los atajos de Vitrum (Super, Alt+Espacio…) lanzan un dbus-send: no son apps del dock
                    readonly property bool helper: /^org\.vitrum\.(launchpad|spotlight-atajo|vistarapida)/.test(String(model.AppId || ""))
                    visible: !helper
                    DockIcon {
                        visible: !parent.helper
                        icon: model.decoration
                        name: model.AppName || model.display
                        appId: String(model.AppId || "")
                        hasWindows: model.IsWindow === true
                        running: model.IsWindow === true
                        active: model.IsActive === true
                        starting: model.IsStartup === true
                        onClicked: dock.clickApp(index, model, this)
                        onMenuRequested: (x, y) => dockMenu.openFor(index, model, this, x, y)
                    }
                    DockIcon {
                        visible: index === 0
                        icon: "vitrum-launchpad"
                        name: "Launchpad"
                        onClicked: ShellBus.ToggleLaunchpad()
                    }
                }
            }
            Item {
                width: dock.vertical ? dock.tile : 13
                height: dock.vertical ? 13 : dock.tile
                // separador de macOS: 1 px, el 75 % del alto de la barra, centrado en ella;
                // blanco al 35 % (oscuro) o negro al 40 % (claro)
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: dock.vertical ? 0 : 2.5 * dock.tile / 64
                    anchors.horizontalCenterOffset: dock.position === "left" ? -2.5 * dock.tile / 64 : dock.position === "right" ? 2.5 * dock.tile / 64 : 0
                    width: dock.vertical ? Math.round(dock.barH * 0.75) : 1
                    height: dock.vertical ? 1 : Math.round(dock.barH * 0.75)
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.40)
                }
            }
            DockIcon {
                icon: dock.trashFull ? "user-trash-full" : "user-trash"
                name: "Papelera"
                onClicked: Sys.detached("dolphin", ["trash:/"])
            }
        }

        // Etiqueta con el nombre de la app: píldora con piquito hacia el icono, como en macOS
        Item {
            id: tip
            visible: dock.hoverName !== "" && dock.revealed
            readonly property int pad: 12
            width: tipText.implicitWidth + pad * 2
            height: 28
            x: dock.position === "bottom" ? Math.round(dock.hoverPos.x - width / 2)
             : dock.position === "left" ? dock.hoverPos.x + 12 : dock.hoverPos.x - width - 12
            y: dock.position === "bottom" ? dock.hoverPos.y - height - 12 : Math.round(dock.hoverPos.y - height / 2)
            readonly property color fill: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.96) : Qt.rgba(0.93, 0.93, 0.94, 0.97)
            readonly property color edge: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14)
            // piquito
            Rectangle {
                width: 10; height: 10; rotation: 45; color: tip.fill
                border.width: 0.5; border.color: tip.edge
                x: dock.position === "bottom" ? (tip.width - width) / 2 : dock.position === "left" ? -4 : tip.width - 6
                y: dock.position === "bottom" ? tip.height - 6 : (tip.height - height) / 2
            }
            Rectangle {
                anchors.fill: parent; radius: 7
                color: tip.fill
                border.width: 0.5; border.color: tip.edge
            }
            Txt { id: tipText; anchors.centerIn: parent; text: dock.hoverName; font.pixelSize: 14 }
        }
    }

    // Menú contextual de cada icono: menú nativo (lo dibuja Darkly, como el del escritorio y el de las apps)
    QtObject {
        id: dockMenu
        property bool visible: false
        function openFor(index, model, item, x, y) {
            const launcher = String(model.LauncherUrlWithoutIcon || "")
            const kept = launcher !== "" && dock.pinned.indexOf(dock.launcherId(launcher)) >= 0
            const isWin = model.IsWindow === true
            const items = [], acts = []
            const add = (text, f) => { items.push({ text: text }); acts.push(f) }
            const sep = () => { items.push({ separator: true }); acts.push(null) }
            // muchas apps no declaran que admiten varias instancias, pero abren otra ventana al lanzarlas de nuevo
            const appId = String(model.AppId || "")
            if (model.CanLaunchNewInstance !== false || appId) {
                add("Nueva ventana", () => model.CanLaunchNewInstance !== false ? tasks.requestNewInstance(tasks.makeModelIndex(index))
                                                                             : Sys.launch(appId))
                sep()
            }
            add(kept ? "Eliminar del Dock" : "Mantener en el Dock", () => {
                const id = dock.launcherId(launcher)
                const list = dock.pinned.slice()
                if (kept) list.splice(list.indexOf(id), 1); else list.push(id)
                dock.save(list)
            })
            if (isWin) { sep(); add("Salir", () => tasks.requestClose(tasks.makeModelIndex(index))) }
            // opciones del Dock, como al hacer clic derecho en el separador en macOS
            sep()
            add(dock.autohide ? "Desactivar ocultación" : "Activar ocultación",
                () => { Sys.writeConf("vitrumrc", ["Dock"], "Autohide", dock.autohide ? "false" : "true"); dock.reload() })
            add(dock.magnify ? "Desactivar ampliación" : "Activar ampliación",
                () => { Sys.writeConf("vitrumrc", ["Dock"], "Magnification", dock.magnify ? "false" : "true"); dock.reload() })
            add("Preferencias del Dock…", () => Sys.detached(Sys.home() + "/.local/bin/vitrum-ajustes", ["dock"]))
            // encima del icono, centrado (o a su lado con el Dock vertical)
            const r = item.mapToItem(null, 0, 0)
            visible = true
            const chosen = Sys.nativeMenu(dock, r.x, r.y, item.width, item.height, items, dock.position)
            visible = false
            if (chosen >= 0 && acts[chosen]) acts[chosen]()
        }
    }

    onTileChanged: Qt.callLater(updateRegions)
    onAutohideChanged: Qt.callLater(updateRegions)
    onCoveredChanged: Qt.callLater(updateRegions)
    Component.onCompleted: { reload(); Theme.refresh(); Qt.callLater(updateRegions) }
}
