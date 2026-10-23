import QtQuick

// Escritorio de Vitrum: dock, Launchpad y Spotlight en un solo proceso (se abren al instante).
QtObject {
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
    property var primaryWatch: Connections {
        target: Sys
        function onFinished(tag, code, out) {
            if (tag !== "vitrum-primaria" || code !== 0) return
            try {
                const o = JSON.parse(out).outputs.filter(x => x.enabled).sort((a, b) => a.priority - b.priority)[0]
                const s = o ? Qt.application.screens.find(x => x.name === o.name) : null
                if (s && (!primary || primary.name !== s.name)) { primary = s; dock.moveTo(s) }
            } catch (e) {}
        }
    }
    // El esquema de color puede cambiar en cualquier momento (modo claro/oscuro)
    property var themeWatch: Timer { interval: 1500; running: true; repeat: true; onTriggered: { Theme.refresh(); dock.reload() } }
    Component.onCompleted: Theme.refresh()
}
