import QtQuick
import org.kde.taskmanager as TaskManager

// Escritorio de Vitrum: dock, Launchpad y Spotlight en un solo proceso (se abren al instante).
QtObject {
    id: shell
    property var dock: Dock { visible: true }
    property var launchpad: Launchpad {}
    property var spotlight: Spotlight {}
    property var controlCenter: ControlCenter {}
    // Las peticiones que llegan mientras las ventanas aún se crean (arranque por D-Bus) se aplazan
    property bool ready: false
    property var pending: null
    property var startup: Timer { interval: 600; running: true; onTriggered: { ready = true; if (pending) pending(); pending = null } }
    function later(f) { if (ready) f(); else pending = f }
    property var bus: Connections {
        target: ShellBus
        function onLaunchpadRequested() {
            later(() => {
                place(launchpad)
                launchpad.toggle()
            })
        }
        function onSpotlightRequested() { later(() => { place(spotlight); spotlight.toggle() }) }
        function onPreviewRequested(app) { dock.debugPreview(app) }
        function onControlCenterViewRequested(v) { if (!controlCenter.visible) { place(controlCenter); controlCenter.open2() } controlCenter.open(v) }
        function onControlCenterRequested() { later(() => { place(controlCenter); controlCenter.toggle() }) }
        function onSearchRequested(text) { later(() => { place(spotlight); spotlight.search(text) }) }
    }
    property var dockOverLaunchpad: Binding { target: dock; property: "overLaunchpad"; value: launchpad.shown }
    // Pantalla principal (Ajustes → Pantallas): el dock vive en ella y Launchpad/Spotlight se abren en ella
    property var primary: null
    // Spotlight, Launchpad y el Centro de Control los coloca KWin en la pantalla activa
    // (LayerShell wantsToBeOnActiveScreen); antes se fijaba aquí la pantalla y, tras cambiar la principal,
    // la primera apertura salía en la anterior
    function place(w) {}
    property var primaryPoll: Timer {
        interval: 2500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: Sys.runAsync("vitrum-primaria", "kscreen-doctor", ["-j"])
    }
    // Pantallas que desaparecen y vuelven (KVM, monitor apagado o desenchufado): cuando la lista de pantallas se
    // estabiliza, se vuelve a colocar el dock en la principal recreando su superficie
    property bool remapPending: false
    property var screensWatch: Connections {
        target: Qt.application
        function onScreensChanged() { screensSettle.restart() }
    }
    property var screensSettle: Timer {
        interval: 1200
        onTriggered: {
            if (!Qt.application.screens.length) return
            remapPending = true
            Sys.runAsync("vitrum-primaria", "kscreen-doctor", ["-j"])
        }
    }
    property var primaryWatch: Connections {
        target: Sys
        function onFinished(tag, code, out) {
            if (tag !== "vitrum-primaria" || code !== 0) return
            try {
                const o = JSON.parse(out).outputs.filter(x => x.enabled).sort((a, b) => a.priority - b.priority)[0]
                const s = o ? Qt.application.screens.find(x => x.name === o.name) : null
                if (s && (!primary || primary.name !== s.name || remapPending)) {
                    primary = s
                    dock.moveTo(s, remapPending)
                    syncDocks(remapPending)
                    remapPending = false
                }
            } catch (e) {}
        }
    }
    // Docks de las pantallas secundarias: ocultos siempre, salen al llevar el puntero al borde de su pantalla
    // (para cambiar de app sin ir hasta la principal). Solo donde ese borde es un borde real: si hay otra
    // pantalla pegada a ese lado, el puntero pasa de largo y no debe sacarlo.
    property var dockComp: Component { Dock { secondary: true } }
    property var extraDocks: ({})
    function edgeFree(s) {
        const pos = dock.position
        return !Qt.application.screens.some(o => {
            if (o === s) return false
            if (pos === "bottom") return o.virtualY === s.virtualY + s.height && o.virtualX < s.virtualX + s.width && o.virtualX + o.width > s.virtualX
            const touch = pos === "left" ? o.virtualX + o.width === s.virtualX : o.virtualX === s.virtualX + s.width
            return touch && o.virtualY < s.virtualY + s.height && o.virtualY + o.height > s.virtualY
        })
    }
    function syncDocks(force) {
        // extraDocks se copia al leerlo (property var): se trabaja sobre una copia y se vuelve a asignar
        const docks = Object.assign({}, extraDocks), want = {}
        if (primary) for (const s of Qt.application.screens) if (s.name !== primary.name && edgeFree(s)) want[s.name] = s
        for (const n of Object.keys(docks)) {
            if (force || !want[n] || docks[n].target.name !== n) { docks[n].visible = false; docks[n].destroy(); delete docks[n] }
        }
        for (const n of Object.keys(want)) {
            if (docks[n]) continue
            const d = dockComp.createObject(shell)
            d.target = want[n]
            d.visible = true
            d.moveTo(want[n], true)
            docks[n] = d
        }
        extraDocks = docks
    }
    // Spectacle (captura de pantalla): Launchpad está en la capa superior y Spotlight/Centro de Control en la de
    // superposición, con el teclado: tapaban el editor de Spectacle y se quedaban con Esc (que cerraba la captura).
    // Al arrancar Spectacle o aparecer una ventana suya se cierran, con un pequeño retraso para que la captura
    // los incluya (como en macOS).
    function closeOverlays() {
        if (launchpad.shown) launchpad.close2()
        if (spotlight.visible) spotlight.close2()
        if (controlCenter.visible) controlCenter.close2()
    }
    property var spectacleTimer: Timer { interval: 700; onTriggered: closeOverlays() }
    property var spectacleWatch: Connections {
        target: Sys
        function onServiceRegistered(name) { if (name === "org.kde.spectacle") spectacleTimer.restart() }
    }
    property var spectacleWindows: Instantiator {
        model: TaskManager.TasksModel { groupMode: TaskManager.TasksModel.GroupDisabled; filterByScreen: false; filterByVirtualDesktop: false; filterByActivity: false }
        delegate: QtObject {
            required property var model
            readonly property bool spectacle: /spectacle/i.test(String(model.AppId || ""))
            readonly property bool active: spectacle && model.IsActive === true
            Component.onCompleted: if (spectacle) spectacleTimer.restart()
            onActiveChanged: if (active) spectacleTimer.restart()
        }
    }
    // El esquema de color puede cambiar en cualquier momento (modo claro/oscuro)
    property var themeWatch: Timer { interval: 1500; running: true; repeat: true; onTriggered: {
        Theme.refresh(); dock.reload()
        for (const n of Object.keys(extraDocks)) extraDocks[n].reload()
        syncDocks(false)        // por si cambió el borde del dock
    } }
    Component.onCompleted: { Theme.refresh(); Sys.watchService("org.kde.spectacle") }
}
