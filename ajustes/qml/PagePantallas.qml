import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

Page {
    id: p
    title: "Pantallas"
    property var outputs: []
    property int sel: 0
    readonly property var o: outputs[sel] || null
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]

    function refresh() {
        try {
            const j = JSON.parse(Sys.run("kscreen-doctor", ["-j"], 6000))
            // la salida JSON no dice si la pantalla admite HDR; la de texto sí ("HDR: incapable")
            const txt = Sys.run("kscreen-doctor", ["-o"], 6000).replace(/\x1b\[[0-9;]*m/g, "")
            const hdrCap = {}
            for (const block of txt.split(/^Output: /m).slice(1)) {
                const name = block.split(/\s+/)[1]
                const m = block.match(/HDR: (\w+)/)
                hdrCap[name] = !!m && m[1] !== "incapable"
            }
            outputs = j.outputs.filter(x => x.connected).map(x => Object.assign(x, { hdrCapable: !!hdrCap[x.name] }))
        } catch (e) { outputs = [] }
    }
    Component.onCompleted: { refresh(); refreshBrillo() }
    // Brillo por DDC/CI a través de PowerDevil (KWin no siempre lo expone en todas las pantallas)
    property var brillo: ({})
    function refreshBrillo() {
        const b = {}
        for (const l of Sys.run(Sys.home() + "/.local/bin/vitrum-brillo", [], 6000).split("\n")) {
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
    Connections { target: Sys; function onFinished(tag) { if (tag === "kscreen") p.refresh() } }

    // Miniaturas de los monitores, como en macOS
    Card {
        RowItem {
            minHeight: 120
            title: ""
            Row {
                spacing: 18
                Repeater {
                    model: p.outputs
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 120 * Math.min(1.3, modelData.size.width / 1920); height: width * modelData.size.height / Math.max(1, modelData.size.width)
                            radius: 6
                            color: index === p.sel ? Theme.accent : Theme.switchOff
                            border.width: 3; border.color: Theme.dark ? "#111" : "#333"
                            // la pantalla principal lleva la barra de menús, como en macOS
                            Rectangle { visible: modelData.priority === 1; x: 3; y: 3; width: parent.width - 6; height: 5; color: "white"; opacity: 0.85 }
                            MouseArea { anchors.fill: parent; onClicked: p.sel = index }
                        }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; font.pixelSize: Theme.smallSize; color: index === p.sel ? Theme.text : Theme.secondary }
                    }
                }
            }
        }
    }
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
        MacButton { text: "Disposición y avanzado…"; onClicked: p.kcm("kcm_kscreen") }
    }
}
