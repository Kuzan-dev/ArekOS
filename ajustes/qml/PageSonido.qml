import QtQuick
import QtQuick.Layouts

Page {
    id: p
    title: "Sonido"
    property var sinks: []
    property var sources: []
    property string defSink: ""
    property string defSource: ""
    property real outVol: 0
    property real inVol: 0
    property bool outMute: false

    function vol(dev) {
        const ch = dev.volume ? Object.values(dev.volume) : []
        return ch.length ? parseInt(ch[0].value_percent) : 0
    }
    function refresh() {
        try {
            sinks = JSON.parse(Sys.run("pactl", ["-f", "json", "list", "sinks"]))
            sources = JSON.parse(Sys.run("pactl", ["-f", "json", "list", "sources"])).filter(s => !s.monitor_source && s.name.indexOf(".monitor") < 0)
        } catch (e) { sinks = []; sources = [] }
        defSink = Sys.run("pactl", ["get-default-sink"]).trim()
        defSource = Sys.run("pactl", ["get-default-source"]).trim()
        const s = sinks.find(x => x.name === defSink); outVol = s ? vol(s) : 0; outMute = s ? s.mute : false
        const m = sources.find(x => x.name === defSource); inVol = m ? vol(m) : 0
    }
    Component.onCompleted: refresh()

    SectionHeader { text: "Efectos de sonido" }
    Card {
        RowItem {
            title: "Reproducir efectos de sonido de la interfaz"
            MacSwitch { checked: Sys.readConf("kdeglobals", ["Sounds"], "Enable", "true") === "true"; onToggled: (v) => Sys.writeConf("kdeglobals", ["Sounds"], "Enable", v ? "true" : "false") }
        }
        RowItem {
            title: "Sonido de alerta"
            MacPopup {
                readonly property var themes: Sys.listDir("/usr/share/sounds", [], true).concat(Sys.listDir(Sys.home() + "/.local/share/sounds", [], true))
                    .filter(d => Sys.exists(d + "/index.theme")).map(d => d.split("/").pop())
                model: themes.map(t => t === "ocean" ? "Océano" : t === "freedesktop" ? "Freedesktop" : t)
                currentIndex: Math.max(0, themes.indexOf(Sys.readConf("kdeglobals", ["Sounds"], "Theme", "ocean")))
                onActivated: (i) => Sys.writeConf("kdeglobals", ["Sounds"], "Theme", themes[i])
            }
        }
        RowItem {
            title: "Reproducir sonido al cambiar el volumen"
            MacSwitch {
                checked: Sys.readConf("plasmaparc", ["General"], "AudioFeedback", "true") === "true"
                onToggled: (v) => Sys.writeConf("plasmaparc", ["General"], "AudioFeedback", v ? "true" : "false")
            }
        }
    }
    SectionHeader { text: "Salida" }
    Card {
        RowItem {
            title: "Volumen de salida"
            Txt { text: "🔈"; color: Theme.secondary }
            MacSlider {
                width: 200; from: 0; to: 100; value: p.outVol
                onMoved: (v) => Sys.detached("pactl", ["set-sink-volume", "@DEFAULT_SINK@", Math.round(v) + "%"])
            }
            Txt { text: "🔊"; color: Theme.secondary }
        }
        RowItem {
            title: "Silenciar"
            MacSwitch { checked: p.outMute; onToggled: (v) => Sys.detached("pactl", ["set-sink-mute", "@DEFAULT_SINK@", v ? "1" : "0"]) }
        }
    }
    Card {
        Repeater {
            model: p.sinks
            RowItem {
                title: (modelData.properties && modelData.properties["node.nick"]) || (modelData.description !== "(null)" ? modelData.description : modelData.name)
                subtitle: modelData.name === p.defSink ? "En uso" : ""
                tileIcon: "audio-speakers-symbolic"
                tileColor: modelData.name === p.defSink ? Theme.tile.pink : Theme.tile.grey
                Txt { visible: modelData.name === p.defSink; text: "✓"; color: Theme.accent; font.pixelSize: 15 }
                MacButton { visible: modelData.name !== p.defSink; text: "Usar"; onClicked: { Sys.run("pactl", ["set-default-sink", modelData.name]); p.refresh() } }
            }
        }
    }
    SectionHeader { text: "Entrada" }
    Card {
        RowItem {
            title: "Volumen de entrada"
            MacSlider {
                width: 200; from: 0; to: 100; value: p.inVol
                onMoved: (v) => Sys.detached("pactl", ["set-source-volume", "@DEFAULT_SOURCE@", Math.round(v) + "%"])
            }
        }
        Repeater {
            model: p.sources
            RowItem {
                title: (modelData.properties && modelData.properties["node.nick"]) || (modelData.description !== "(null)" ? modelData.description : modelData.name)
                subtitle: modelData.name === p.defSource ? "En uso" : ""
                Txt { visible: modelData.name === p.defSource; text: "✓"; color: Theme.accent; font.pixelSize: 15 }
                MacButton { visible: modelData.name !== p.defSource; text: "Usar"; onClicked: { Sys.run("pactl", ["set-default-source", modelData.name]); p.refresh() } }
            }
        }
    }
    KdeOptions {
        page: p
        items: [
            { t: "Audio", s: "Volumen por app, perfiles y dispositivos", k: "kcm_pulseaudio", icon: "audio-volume-high-symbolic" },
            { t: "Sonidos del sistema", s: "Tema de sonidos de las alertas", k: "kcm_soundtheme", icon: "preferences-desktop-sound-symbolic" }
        ]
    }
}
