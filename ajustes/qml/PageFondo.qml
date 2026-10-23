import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Fondo de pantalla"
    // Paquetes de fondos (carpetas con contents/images) e imágenes sueltas
    function collect(dir) {
        const out = []
        for (const d of Sys.listDir(dir, [], true)) {
            const imgs = Sys.listDir(d + "/contents/images", ["*.jpg", "*.jpeg", "*.png", "*.webp"])
            if (imgs.length) out.push({ name: d.split("/").pop(), path: d, thumb: imgs[0] })
        }
        for (const f of Sys.listDir(dir, ["*.jpg", "*.jpeg", "*.png", "*.webp"])) out.push({ name: f.split("/").pop(), path: f, thumb: f })
        return out
    }
    readonly property var walls: collect(Sys.home() + "/.local/share/wallpapers").concat(collect("/usr/share/wallpapers"))
    readonly property string rc: "plasma-org.kde.plasma.desktop-appletsrc"

    // Fondo por pantalla (como macOS con varias pantallas). Plasma tiene un escritorio por pantalla: se leen
    // con su intérprete de scripts (pantalla, geometría e imagen) y se emparejan con el nombre del monitor.
    property var desks: []
    property var screens: []          // [{ name: "DP-2", label: "Mi Monitor", x, y }]
    property int target: 0            // 0 = todas; si no, índice+1 en screens
    function q(js) { return Sys.run("qdbus-qt6", ["org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", js], 5000).trim() }
    function refreshDesks() {
        try {
            desks = JSON.parse(q("print(JSON.stringify(desktops().map(function(d){ d.currentConfigGroup = ['Wallpaper','org.kde.image','General'];"
                                 + " var g = screenGeometry(d.screen); return { screen: d.screen, x: g.x, y: g.y, img: d.readConfig('Image') } })))"))
        } catch (e) { desks = [] }
        const labels = {}
        for (const l of Sys.run(Sys.home() + "/.local/bin/vitrum-brillo", [], 5000).split("\n")) {
            const f = l.split("|"); if (f.length === 4 && f[0]) labels[f[0]] = f[2].replace(/^(LG Electronics|Xiaomi Corporation) /, "")
        }
        screens = Qt.application.screens.map(sc => ({ name: sc.name, label: labels[sc.name] || sc.name, x: sc.virtualX, y: sc.virtualY }))
    }
    Component.onCompleted: refreshDesks()
    function screenIndexOf(sc) { const d = desks.find(d => d.x === sc.x && d.y === sc.y); return d ? d.screen : -1 }
    readonly property string current: {
        const sc = target > 0 ? screens[target - 1] : null
        const d = sc ? desks.find(d => d.x === sc.x && d.y === sc.y) : desks[0]
        return d && d.img ? String(d.img).replace("file://", "").replace(/\/$/, "") : ""
    }
    function applyWall(path) {
        if (target === 0) Sys.detached("plasma-apply-wallpaperimage", [path])
        else {
            const n = screenIndexOf(screens[target - 1])
            p.plasmaScript("desktops().forEach(function(d){ if (d.screen != " + n + ") return; d.wallpaperPlugin = 'org.kde.image';"
                           + " d.currentConfigGroup = ['Wallpaper','org.kde.image','General']; d.writeConfig('Image', 'file://" + path.replace(/'/g, "\\'") + "') })")
        }
        refreshLater.restart()
    }
    Timer { id: refreshLater; interval: 800; onTriggered: p.refreshDesks() }

    function thumbOf(path) {
        const w = walls.find(x => x.path === path)
        if (w) return w.thumb
        const imgs = Sys.listDir(path + "/contents/images", ["*.jpg", "*.jpeg", "*.png", "*.webp"])
        return imgs.length ? imgs[0] : path
    }

    Card {
        RowItem {
            visible: p.screens.length > 1
            title: "Pantalla"
            subtitle: "Cada pantalla puede tener su propio fondo"
            MacPopup {
                model: ["Todas las pantallas"].concat(p.screens.map(sc => sc.label))
                currentIndex: p.target
                onActivated: (i) => p.target = i
            }
        }
        RowItem {
            minHeight: 110
            title: p.current ? p.current.split("/").pop() : "Fondo actual"
            subtitle: "Los fondos dinámicos cambian con el aspecto claro u oscuro."
            Rectangle {
                width: 150; height: 92; radius: 8; clip: true; color: Theme.switchOff
                Image { anchors.fill: parent; source: p.current ? "file://" + p.thumbOf(p.current) : ""; fillMode: Image.PreserveAspectCrop; sourceSize.width: 300; asynchronous: true }
            }
        }
    }
    // Ajuste de la imagen (macOS) = FillMode del fondo de KDE, aplicado a todos los escritorios
    readonly property var fillModes: [2, 1, 0, 6, 3]
    property int fill: {
        for (const c of Sys.confGroups(rc, ["Containments"]))
            if (Sys.readConf(rc, ["Containments", c], "wallpaperplugin") === "org.kde.image")
                return Number(Sys.readConf(rc, ["Containments", c, "Wallpaper", "org.kde.image", "General"], "FillMode", "2"))
        return 2
    }
    Card {
        RowItem {
            title: "Ajuste"
            MacPopup {
                model: ["Llenar la pantalla", "Ajustar a la pantalla", "Estirar para llenar", "Centrar", "Mosaico"]
                currentIndex: Math.max(0, p.fillModes.indexOf(p.fill))
                onActivated: (i) => {
                    p.fill = p.fillModes[i]
                    p.plasmaScript("desktops().forEach(function(d){ d.currentConfigGroup = ['Wallpaper','org.kde.image','General']; d.writeConfig('FillMode', " + p.fillModes[i] + ") })")
                }
            }
        }
        RowItem {
            title: "Añadir una foto…"
            subtitle: "Elige cualquier imagen como fondo"
            chevron: true
            onClicked: Sys.runAsync("fondo-foto", "kdialog", ["--getopenfilename", Sys.home() + "/Imágenes", "image/jpeg image/png image/webp image/heic"])
        }
    }
    Connections {
        target: Sys
        function onFinished(tag, code, out) {
            if (tag === "fondo-foto" && code === 0 && out.trim()) p.applyWall(out.trim())
        }
    }
    SectionHeader { text: "Fondos de pantalla" }
    GridLayout {
        Layout.fillWidth: true
        columns: Math.max(2, Math.floor(width / 140))
        columnSpacing: 10; rowSpacing: 10
        Repeater {
            model: p.walls
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.62
                radius: 8; clip: true
                color: Theme.switchOff
                border.width: p.current === modelData.path ? 3 : 0
                border.color: Theme.accent
                Image {
                    anchors.fill: parent; anchors.margins: parent.border.width
                    source: "file://" + modelData.thumb; fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 280; asynchronous: true
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: p.applyWall(modelData.path)
                }
            }
        }
    }

    KdeOptions {
        page: p
        items: [
            { t: "Fondo del escritorio", s: "Presentación de diapositivas, imagen del día y más", k: "kcm_wallpaper", icon: "preferences-desktop-wallpaper-symbolic" }
        ]
    }
}
