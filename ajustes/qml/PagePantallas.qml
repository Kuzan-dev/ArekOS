import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Qt5Compat.GraphicalEffects as GE

Page {
    id: p
    title: "Pantallas"
    property var outputs: []
    property int sel: 0
    readonly property var o: outputs[sel] || null
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]

    // se consulta en segundo plano: mientras KWin aplica un cambio, kscreen-doctor tarda y congelaba la ventana
    property string ksJson: ""
    property string ksText: ""
    function refresh() {
        Sys.runAsync("ks-json", "kscreen-doctor", ["-j"])
        Sys.runAsync("ks-text", "kscreen-doctor", ["-o"])
    }
    function parseOutputs() {
        if (!ksJson || !ksText) return
        try {
            const j = JSON.parse(ksJson)
            // la salida JSON no dice si la pantalla admite HDR; la de texto sí ("HDR: incapable")
            const txt = ksText.replace(/\x1b\[[0-9;]*m/g, "")
            const hdrCap = {}
            for (const block of txt.split(/^Output: /m).slice(1)) {
                const name = block.split(/\s+/)[1]
                const m = block.match(/HDR: (\w+)/)
                hdrCap[name] = !!m && m[1] !== "incapable"
            }
            outputs = j.outputs.filter(x => x.connected).map(x => Object.assign(x, { hdrCapable: !!hdrCap[x.name] }))
            // la disposición ya refleja lo que se arrastró (o lo que se revirtió)
            pendingPos = ({})
        } catch (e) {}
        ksJson = ""; ksText = ""
    }
    // posición elegida al arrastrar, mientras KWin la aplica (el monitor no vuelve atrás entretanto)
    property var pendingPos: ({})
    Component.onCompleted: { refresh(); refreshBrillo(); refreshNames() }
    // nombre comercial de cada monitor (EDID), como en macOS ("LG ULTRAGEAR", "Mi Monitor")
    property var names: ({})
    function refreshNames() {
        const code = "import glob\nfor d in sorted(glob.glob('/sys/class/drm/card*-*')):\n" +
            "    try: e=open(d+'/edid','rb').read()\n    except Exception: continue\n    n=''\n" +
            "    for i in range(54,126,18):\n" +
            "        if len(e)>i+5 and e[i:i+3]==b'\\0\\0\\0' and e[i+3]==0xfc: n=e[i+5:i+18].split(b'\\n')[0].decode(errors='ignore').strip()\n" +
            "    if e: print(d.split('-',1)[1]+'|'+n)\n"
        const r = {}
        for (const l of Sys.run("python3", ["-c", code], 4000).split("\n")) { const f = l.split("|"); if (f.length === 2 && f[1]) r[f[0]] = f[1] }
        names = r
    }
    function label(out) { return names[out.name] || out.name }
    // fondo del escritorio para las miniaturas
    readonly property string wallpaper: {
        const m = Sys.readText(Sys.home() + "/.config/plasma-org.kde.plasma.desktop-appletsrc").match(/^Image=(.+)$/m)
        if (!m) return ""
        let u = m[1].trim()
        if (u.indexOf("file://") !== 0) u = "file://" + u
        // carpeta de fondo dinámico (paquete): usa su primera imagen
        if (!/\.(jpe?g|png|webp|avif|bmp)$/i.test(u)) {
            const dir = u.replace("file://", "").replace(/\/$/, "") + "/contents/images"
            const imgs = Sys.listDir(dir)
            return imgs.length ? "file://" + imgs[0] : ""   // listDir da rutas completas
        }
        return u
    }
    // Brillo por DDC/CI a través de PowerDevil (KWin no siempre lo expone en todas las pantallas)
    property var brillo: ({})
    function refreshBrillo() { Sys.runAsync("brillo-lista", Sys.home() + "/.local/bin/vitrum-brillo", []) }
    function parseBrillo(out) {
        const b = {}
        for (const l of out.split("\n")) {
            const f = l.split("|")
            if (f.length === 4 && f[0]) b[f[0]] = { obj: f[1], label: f[2], pct: Number(f[3]) }
        }
        brillo = b
    }
    readonly property var br: o ? brillo[o.name] || null : null
    function mode(id) { return o ? o.modes.find(m => m.id === id) : null }
    readonly property var cur: o ? mode(o.currentModeId) : null
    readonly property var sizes: o ? [...new Set(o.modes.map(m => m.size.width + "×" + m.size.height))]
        .sort((a, b) => Number(b.split("×")[0]) * Number(b.split("×")[1]) - Number(a.split("×")[0]) * Number(a.split("×")[1])) : []
    readonly property string curSize: cur ? cur.size.width + "×" + cur.size.height : ""
    readonly property var rates: o ? o.modes.filter(m => m.size.width + "×" + m.size.height === curSize)
        .map(m => Math.round(m.refreshRate)).filter((v, i, a) => a.indexOf(v) === i).sort((a, b) => b - a) : []
    readonly property var rotations: [1, 2, 4, 8]
    function apply(args) { Sys.runAsync("kscreen", "kscreen-doctor", args) }
    // Cambios que pueden dejar la pantalla inutilizable (HDR en algunas NVIDIA, modos no soportados): se
    // aplican con vitrum-pantalla-cambio, que los revierte solo si no se confirman en 15 s
    property string pendingId: ""
    property var pendingRevert: []
    function applySafe(args, revert) {
        pendingId = "c" + Date.now()
        pendingRevert = revert
        Sys.detached(Sys.home() + "/.local/bin/vitrum-pantalla-cambio", [pendingId, args.join(" "), revert.join(" ")])
        confirm.secs = 15; confirm.open()
        refreshLater.restart()
    }
    function keep() { Sys.run("touch", [Sys.home() + "/.cache/vitrum-pantalla/" + pendingId + ".ok"]); confirm.close(); p.refresh() }
    Timer { id: refreshLater; interval: 1500; onTriggered: p.refresh() }
    QQC.Popup {
        id: confirm
        property int secs: 15
        parent: QQC.Overlay.overlay
        anchors.centerIn: parent
        modal: true; closePolicy: QQC.Popup.NoAutoClose
        width: 340; padding: 18
        background: Rectangle { radius: 14; color: Theme.windowBg; border.width: 0.5; border.color: Theme.sidebarEdge }
        Timer { running: confirm.visible; interval: 1000; repeat: true; onTriggered: { confirm.secs--; if (confirm.secs <= 0) { confirm.close(); refreshLater.restart() } } }
        contentItem: ColumnLayout {
            spacing: 10
            Txt { Layout.fillWidth: true; text: "¿Quieres mantener estos ajustes de pantalla?"; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Txt { Layout.fillWidth: true; text: "Se recuperarán los ajustes anteriores en " + confirm.secs + " segundos."; color: Theme.secondary; font.pixelSize: Theme.smallSize; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                MacButton { text: "Revertir"; onClicked: { p.keep(); p.apply(p.pendingRevert); refreshLater.restart() } }
                MacButton { text: "Mantener"; primary: true; onClicked: p.keep() }
            }
        }
    }
    HotCorners { id: hotCornersP }
    Connections {
        target: Sys
        function onFinished(tag, code, out) {
            if (tag === "kscreen") p.refresh()
            else if (tag === "ks-json") { p.ksJson = code === 0 ? out : "{\"outputs\":[]}"; p.parseOutputs() }
            else if (tag === "ks-text") { p.ksText = out || " "; p.parseOutputs() }
            else if (tag === "brillo-lista") p.parseBrillo(out || "")
        }
    }

    // Disposición de los monitores, como en macOS Sequoia: a escala y en su posición real (también la altura
    // relativa), con el fondo de pantalla dentro, la barra de menús en la principal y el nombre debajo.
    // Se arrastran para colocarlos; al soltar se pegan al borde del otro monitor y se aplica (con confirmación).
    Card {
        Item {
            id: arr
            Layout.fillWidth: true
            Layout.preferredHeight: p.outputs.length > 1 ? 210 : 170
            // geometría lógica de cada salida (tamaño del modo / escala, girado si hace falta)
            function geo(o) {
                const rot = o.rotation === 2 || o.rotation === 8
                const w = (rot ? o.size.height : o.size.width) / (o.scale || 1)
                const h = (rot ? o.size.width : o.size.height) / (o.scale || 1)
                const q = p.pendingPos[o.name]
                return { x: q ? q.x : o.pos.x, y: q ? q.y : o.pos.y, w: w, h: h }
            }
            readonly property var geos: p.outputs.map(o => geo(o))
            readonly property rect box: {
                if (!geos.length) return Qt.rect(0, 0, 1, 1)
                let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
                for (const g of geos) { x0 = Math.min(x0, g.x); y0 = Math.min(y0, g.y); x1 = Math.max(x1, g.x + g.w); y1 = Math.max(y1, g.y + g.h) }
                return Qt.rect(x0, y0, x1 - x0, y1 - y0)
            }
            // escala: deja margen para el nombre y para arrastrar
            readonly property real k: Math.min((width - 120) / box.width, (height - 56) / box.height, 0.16)
            readonly property real ox: (width - box.width * k) / 2
            readonly property real oy: 16 + (height - 56 - box.height * k) / 2

            // al soltar: posición lógica propuesta → pegada al monitor más cercano → se aplica
            function drop(idx, nx, ny) {
                const g = geos[idx]
                let best = null, bestD = Infinity
                for (let j = 0; j < geos.length; ++j) {
                    if (j === idx) continue
                    const o = geos[j]
                    const clampY = (y) => Math.max(o.y - g.h + 1, Math.min(o.y + o.h - 1, y))
                    const clampX = (x) => Math.max(o.x - g.w + 1, Math.min(o.x + o.w - 1, x))
                    for (const c of [{ x: o.x - g.w, y: clampY(ny) }, { x: o.x + o.w, y: clampY(ny) },
                                     { x: clampX(nx), y: o.y - g.h }, { x: clampX(nx), y: o.y + o.h }]) {
                        // alinear arriba, abajo o al centro si se queda cerca (como el imán de macOS)
                        const vert = c.x === o.x - g.w || c.x === o.x + o.w
                        const snapT = 0.06 * (vert ? o.h : o.w)
                        if (vert) { for (const t of [o.y, o.y + o.h - g.h, o.y + (o.h - g.h) / 2]) if (Math.abs(c.y - t) < snapT) { c.y = t; break } }
                        else { for (const t of [o.x, o.x + o.w - g.w, o.x + (o.w - g.w) / 2]) if (Math.abs(c.x - t) < snapT) { c.x = t; break } }
                        const d = Math.hypot(c.x - nx, c.y - ny)
                        if (d < bestD) { bestD = d; best = c }
                    }
                }
                if (!best) return
                const pos = geos.map((q, j) => j === idx ? { x: Math.round(best.x), y: Math.round(best.y) } : { x: q.x, y: q.y })
                // KWin quiere coordenadas desde 0,0
                const mx = Math.min(...pos.map(q => q.x)), my = Math.min(...pos.map(q => q.y))
                const args = [], revert = [], pend = {}
                p.outputs.forEach((o, j) => {
                    pend[o.name] = { x: pos[j].x - mx, y: pos[j].y - my }
                    args.push("output." + o.name + ".position." + pend[o.name].x + "," + pend[o.name].y)
                    revert.push("output." + o.name + ".position." + o.pos.x + "," + o.pos.y)
                })
                p.pendingPos = pend
                p.applySafe(args, revert)
            }

            Repeater {
                model: p.outputs
                Item {
                    id: mon
                    required property var modelData
                    required property int index
                    readonly property var g: arr.geos[index] || { x: 0, y: 0, w: 1, h: 1 }
                    readonly property bool selected: index === p.sel
                    x: arr.ox + (g.x - arr.box.x) * arr.k
                    y: arr.oy + (g.y - arr.box.y) * arr.k
                    width: g.w * arr.k
                    height: g.h * arr.k
                    z: drag.drag.active ? 2 : 1
                    // marco del monitor (bisel oscuro) con el fondo dentro
                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: "#0b0b0d"
                        border.width: mon.selected ? 3 : 1
                        border.color: mon.selected ? Theme.accent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.35))
                        Image {
                            id: wall
                            anchors.fill: parent; anchors.margins: mon.selected ? 4 : 3
                            source: p.wallpaper
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 400
                            asynchronous: true
                            visible: false
                        }
                        Rectangle { id: wallMask; anchors.fill: wall; radius: 3; visible: false }
                        GE.OpacityMask { anchors.fill: wall; source: wall; maskSource: wallMask; visible: wall.status === Image.Ready }
                        // barra de menús en la pantalla principal
                        Rectangle {
                            visible: mon.modelData.priority === 1
                            x: wall.x; y: wall.y; width: wall.width; height: Math.max(3, wall.height * 0.07)
                            color: "white"; opacity: 0.85
                        }
                    }
                    Txt {
                        anchors.top: parent.bottom; anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: p.label(mon.modelData)
                        font.pixelSize: Theme.smallSize
                        font.weight: mon.selected ? Font.DemiBold : Font.Normal
                        color: mon.selected ? Theme.text : Theme.secondary
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        cursorShape: p.outputs.length > 1 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                        drag.target: p.outputs.length > 1 ? mon : null
                        drag.threshold: 4
                        onPressed: p.sel = mon.index
                        onReleased: {
                            if (!drag.drag.active && Math.abs(mon.x - (arr.ox + (mon.g.x - arr.box.x) * arr.k)) < 1) return
                            const nx = arr.box.x + (mon.x - arr.ox) / arr.k
                            const ny = arr.box.y + (mon.y - arr.oy) / arr.k
                            // queda en la posición elegida (pendingPos) mientras KWin la aplica
                            mon.x = Qt.binding(() => arr.ox + (mon.g.x - arr.box.x) * arr.k)
                            mon.y = Qt.binding(() => arr.oy + (mon.g.y - arr.box.y) * arr.k)
                            arr.drop(mon.index, nx, ny)
                        }
                    }
                }
            }
        }
    }
    Note { visible: p.outputs.length > 1; text: "Arrastra las pantallas para colocarlas como están en tu escritorio. La barra blanca indica la pantalla principal." }
    Card {
        visible: !!p.o
        RowItem {
            title: "Brillo"
            visible: !!p.br || (p.o && p.o.brightness !== undefined)
            Txt { text: "☀"; color: Theme.secondary; font.pixelSize: 11 }
            MacSlider {
                width: 200; from: 0; to: 100; stepSize: 1
                value: p.br ? p.br.pct : (p.o && p.o.brightness !== undefined ? Math.round(p.o.brightness * 100) : 0)
                onReleased: (v) => p.br ? Sys.runAsync("brillo", Sys.home() + "/.local/bin/vitrum-brillo", [p.br.obj, String(Math.round(v))])
                                        : p.apply(["output." + p.o.name + ".brightness." + Math.round(v)])
            }
            Txt { text: "☀"; color: Theme.secondary; font.pixelSize: 16 }
        }
        RowItem {
            title: "Resolución"
            MacPopup {
                model: p.sizes
                currentIndex: p.sizes.indexOf(p.curSize)
                onActivated: (i) => {
                    const best = p.o.modes.filter(m => m.size.width + "×" + m.size.height === p.sizes[i]).sort((a, b) => b.refreshRate - a.refreshRate)[0]
                    p.applySafe(["output." + p.o.name + ".mode." + best.id], ["output." + p.o.name + ".mode." + p.o.currentModeId])
                }
            }
        }
        RowItem {
            title: "Frecuencia de actualización"
            MacPopup {
                model: p.rates.map(r => r + " Hz")
                currentIndex: p.cur ? p.rates.indexOf(Math.round(p.cur.refreshRate)) : 0
                onActivated: (i) => {
                    const m = p.o.modes.find(m => m.size.width + "×" + m.size.height === p.curSize && Math.round(m.refreshRate) === p.rates[i])
                    if (m) p.applySafe(["output." + p.o.name + ".mode." + m.id], ["output." + p.o.name + ".mode." + p.o.currentModeId])
                }
            }
        }
        RowItem {
            title: "Escala"
            MacPopup {
                model: p.scales.map(s => Math.round(s * 100) + " %")
                currentIndex: p.o ? Math.max(0, p.scales.indexOf(p.o.scale)) : 0
                onActivated: (i) => p.applySafe(["output." + p.o.name + ".scale." + p.scales[i]], ["output." + p.o.name + ".scale." + p.o.scale])
            }
        }
        RowItem {
            title: "Rotación"
            MacPopup {
                readonly property var vals: ["normal", "left", "inverted", "right"]
                model: ["Estándar", "90°", "180°", "270°"]
                currentIndex: p.o ? Math.max(0, p.rotations.indexOf(p.o.rotation)) : 0
                onActivated: (i) => p.applySafe(["output." + p.o.name + ".rotation." + vals[i]], ["output." + p.o.name + ".rotation." + vals[Math.max(0, p.rotations.indexOf(p.o.rotation))]])
            }
        }
        RowItem {
            title: "Alto rango dinámico"
            subtitle: "Muestra contenido HDR con más brillo y color"
            visible: p.o ? p.o.hdrCapable : false
            MacSwitch {
                checked: p.o ? !!p.o.hdr : false
                // solo HDR (activar a la vez la gama amplia hacía fallar el cambio de modo en NVIDIA), y con
                // confirmación: si la pantalla se queda bloqueada, se revierte sola a los 15 s
                onToggled: (v) => p.applySafe(["output." + p.o.name + ".hdr." + (v ? "enable" : "disable")],
                                              ["output." + p.o.name + ".hdr." + (v ? "disable" : "enable")])
            }
        }
        RowItem {
            title: "Brillo del contenido SDR"
            subtitle: "Brillo de las apps y del escritorio con HDR activado"
            visible: p.o ? p.o.hdrCapable && !!p.o.hdr : false
            MacSlider {
                width: 200; from: 100; to: 1000; stepSize: 10
                value: p.o && p.o["sdr-brightness"] !== undefined ? p.o["sdr-brightness"] : 300
                onReleased: (v) => p.apply(["output." + p.o.name + ".sdr-brightness." + Math.round(v)])
            }
        }
        // Como en macOS Sequoia: cada pantalla se "usa como" principal o extendida
        RowItem {
            title: "Usar como"
            visible: p.outputs.length > 1
            MacPopup {
                model: ["Pantalla principal", "Pantalla extendida"]
                currentIndex: p.o && p.o.priority === 1 ? 0 : 1
                onActivated: (i) => {
                    if (i === 0) p.apply(["output." + p.o.name + ".priority.1"])
                    else {
                        // la principal pasa a ser otra pantalla
                        const other = p.outputs.find(x => x.name !== p.o.name && x.enabled)
                        if (other) p.apply(["output." + other.name + ".priority.1"])
                    }
                }
            }
        }
    }
    SectionHeader { text: "Night Shift" }
    Card {
        // macOS: "Programar". KWin 6.6 tiene dos modos: siempre, o según el horario de día y noche del sistema
        RowItem {
            title: "Programar"
            MacPopup {
                readonly property bool activo: Sys.readConf("kwinrc", ["NightColor"], "Active", "false") === "true"
                model: ["Desactivado", "Del atardecer al amanecer", "Siempre"]
                currentIndex: !activo ? 0 : Sys.readConf("kwinrc", ["NightColor"], "Mode", "DarkLight") === "Constant" ? 2 : 1
                onActivated: (i) => {
                    Sys.writeConf("kwinrc", ["NightColor"], "Active", i === 0 ? "false" : "true")
                    if (i > 0) Sys.writeConf("kwinrc", ["NightColor"], "Mode", i === 2 ? "Constant" : "DarkLight")
                    p.kwinReconfigure()
                }
            }
        }
        RowItem {
            title: "Horario del atardecer y el amanecer…"
            subtitle: "Según tu ubicación o a horas fijas"
            chevron: true
            onClicked: p.kcm("kcm_nighttime")
        }
        RowItem {
            title: "Temperatura de color"
            Txt { text: "Menos cálida"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            MacSlider {
                width: 160; from: 6500; to: 2800; stepSize: 100
                value: Number(Sys.readConf("kwinrc", ["NightColor"], "NightTemperature", "4500"))
                onReleased: (v) => { Sys.writeConf("kwinrc", ["NightColor"], "NightTemperature", String(Math.round(v))); p.kwinReconfigure() }
            }
            Txt { text: "Más cálida"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        MacButton { text: "Night Shift…"; onClicked: p.kcm("kcm_nightlight") }
        MacButton { text: "Esquinas activas…"; onClicked: { hotCornersP.rev++; hotCornersP.open() } }
        MacButton { text: "Disposición y avanzado…"; onClicked: p.kcm("kcm_kscreen") }
    }
}
