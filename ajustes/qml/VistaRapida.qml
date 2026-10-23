import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC
import QtMultimedia
import org.kde.kirigami as Kirigami

// Vista rápida: previsualiza un archivo sin abrir su app (Espacio/Esc cierra, Intro abre).
Window {
    id: win
    readonly property var info: Sys.fileInfo(quickLookFile)
    readonly property string mime: info.mime || ""
    readonly property string kind: info.dir ? "dir"
        : mime.startsWith("image/") ? "image"
        : mime.startsWith("video/") ? "video"
        : mime.startsWith("audio/") ? "audio"
        : mime === "application/pdf" ? "pdf"
        : (mime.startsWith("text/") || /json|xml|javascript|x-shellscript|x-yaml|toml|x-desktop|x-python|x-ruby|x-perl|sql|x-php|x-csrc|x-c\+\+src|x-sh/.test(mime)) && info.size < 5e6 ? "text"
        : "other"
    property var pdfPages: []

    width: kind === "image" ? Math.min(1000, Math.max(420, img.implicitWidth + 2)) : kind === "other" || kind === "dir" || kind === "audio" ? 520 : 820
    height: kind === "image" ? Math.min(760, Math.max(300, (img.implicitHeight ? img.implicitHeight * (width - 2) / img.implicitWidth : 500) + 46))
          : kind === "other" || kind === "dir" || kind === "audio" ? 300 : 640
    visible: true
    color: "transparent"
    title: info.name || "Vista rápida"

    function human(b) {
        const u = ["bytes", "KB", "MB", "GB", "TB"]; let i = 0
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++ }
        return (i ? b.toFixed(1) : b) + " " + u[i]
    }
    function openFile() { Sys.detached("xdg-open", [quickLookFile]); Qt.quit() }

    Component.onCompleted: {
        Theme.refresh()
        if (kind === "pdf") {
            const dir = "/tmp/vitrum-vistarapida-" + Sys.user()
            Sys.run("bash", ["-c", "rm -rf \"$0\" && mkdir -p \"$0\" && pdftoppm -png -r 90 -f 1 -l 6 \"$1\" \"$0/p\"", dir, quickLookFile], 15000)
            pdfPages = Sys.listDir(dir, ["*.png"])
        }
        Qt.callLater(() => Sys.setBlur(win, 0, 0, win.width, win.height, 12))
        requestActivate()
    }
    onWidthChanged: Qt.callLater(() => Sys.setBlur(win, 0, 0, win.width, win.height, 12))
    onHeightChanged: Qt.callLater(() => Sys.setBlur(win, 0, 0, win.width, win.height, 12))

    Shortcut { sequences: ["Space", "Escape"]; onActivated: Qt.quit() }
    Shortcut { sequences: ["Return", "Enter"]; onActivated: win.openFile() }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.dark ? Qt.rgba(0.14, 0.14, 0.15, 0.82) : Qt.rgba(0.97, 0.97, 0.98, 0.82)
        border.width: 1
        border.color: Theme.sidebarEdge
    }

    // Barra superior
    Item {
        id: bar
        width: parent.width; height: 44
        DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
        TrafficLights { x: 14; anchors.verticalCenter: parent.verticalCenter }
        Txt {
            anchors.centerIn: parent
            width: parent.width - 260
            horizontalAlignment: Text.AlignHCenter
            text: win.info.name || ""
            font.weight: Font.DemiBold
        }
        MacButton {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            text: "Abrir"
            onClicked: win.openFile()
        }
    }

    Item {
        anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
        clip: true

        Image {
            id: img
            visible: win.kind === "image"
            anchors.fill: parent
            source: win.kind === "image" ? "file://" + quickLookFile : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            autoTransform: true
        }

        Item {
            visible: win.kind === "video"
            anchors.fill: parent
            MediaPlayer {
                id: player
                source: win.kind === "video" || win.kind === "audio" ? "file://" + quickLookFile : ""
                videoOutput: vo
                audioOutput: AudioOutput {}
                Component.onCompleted: if (win.kind === "video" || win.kind === "audio") play()
            }
            VideoOutput { id: vo; anchors.fill: parent }
            MouseArea { anchors.fill: parent; onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play() }
        }

        QQC.ScrollView {
            visible: win.kind === "pdf"
            anchors.fill: parent
            contentWidth: availableWidth
            Column {
                width: parent.width
                spacing: 12
                topPadding: 12
                Repeater {
                    model: win.pdfPages
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width - 40, implicitWidth)
                        fillMode: Image.PreserveAspectFit
                        source: "file://" + modelData
                    }
                }
            }
        }

        QQC.ScrollView {
            visible: win.kind === "text"
            anchors.fill: parent
            anchors.margins: 12
            QQC.TextArea {
                readOnly: true
                text: win.kind === "text" ? Sys.readText(quickLookFile) : ""
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                color: Theme.text
                wrapMode: Text.NoWrap
                background: null
                selectByMouse: true
            }
        }

        // Carpetas, audio y cualquier otro tipo: icono grande e información
        RowLayout {
            visible: win.kind === "other" || win.kind === "dir" || win.kind === "audio"
            anchors.centerIn: parent
            spacing: 22
            Kirigami.Icon { source: win.info.icon || "unknown"; fallback: "unknown"; implicitWidth: 128; implicitHeight: 128 }
            ColumnLayout {
                spacing: 4
                Txt { text: win.info.name || ""; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.maximumWidth: 280 }
                Txt { text: win.info.mimeComment || ""; color: Theme.secondary }
                Txt { visible: !win.info.dir; text: win.human(win.info.size || 0); color: Theme.secondary }
                Txt { text: "Modificado: " + Qt.formatDateTime(win.info.modified, "d MMM yyyy, HH:mm"); color: Theme.secondary }
                Txt {
                    visible: win.kind === "audio"
                    text: player.playbackState === MediaPlayer.PlayingState ? "❚❚  Pausa" : "▶  Reproducir"
                    color: Theme.accent
                    MouseArea { anchors.fill: parent; onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play() }
                }
            }
        }
    }
}
