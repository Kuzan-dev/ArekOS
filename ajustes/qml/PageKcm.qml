import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls as QQC
import Qt5Compat.GraphicalEffects as GE

// Páginas que se apoyan en los módulos de KDE, con algunos ajustes rápidos propios.
Page {
    id: p
    readonly property var pages: ({
        privacidad: { title: "Privacidad y seguridad", rows: [
            { t: "Permisos de las apps", k: "kcm_app-permissions", icon: "security-high-symbolic" },
            { t: "Archivos e historial recientes", k: "kcm_recentFiles", icon: "clock-symbolic" },
            { t: "Búsqueda de archivos", k: "kcm_baloofile", icon: "search-symbolic" },
            { t: "Pantalla de bloqueo", go: "bloqueo", icon: "system-lock-screen-symbolic" } ] },
        usuarios: { title: "Usuarios y grupos", rows: [
            { t: "Cuentas de usuario", s: "Nombre, contraseña y otras cuentas", k: "kcm_users", icon: "system-users-symbolic" },
            { t: "Cuentas en línea", k: "kcm_kaccounts", icon: "map-globe-symbolic" } ] },
        contrasenas: { title: "Contraseñas", rows: [
            { t: "Cartera de KDE (llavero)", s: "Contraseñas guardadas de Wi‑Fi, navegadores y apps", run: "kwalletmanager5", icon: "password-copy-symbolic" },
            { t: "Ajustes de la cartera", k: "kcm_kwallet5", icon: "preferences-system-symbolic" } ] },
        impresoras: { title: "Impresoras y escáneres", rows: [
            { t: "Impresoras", s: "Añadir y gestionar impresoras", k: "kcm_printer_manager", icon: "printer-symbolic" } ] }
    })
    readonly property var d: pages[pageId] || { title: "", rows: [] }
    title: d.title

    // Usuarios y grupos: la foto de la cuenta, como en macOS (la foto grande, imágenes para elegir y un archivo)
    Card {
        visible: p.pageId === "usuarios"
        Item {
            Layout.fillWidth: true
            implicitHeight: faceCol.implicitHeight + 32
            ColumnLayout {
                id: faceCol
                x: 16; y: 16
                width: parent.width - 32
                spacing: 14
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Item {
                        Layout.preferredWidth: 72; Layout.preferredHeight: 72
                        width: 72; height: 72
                        Rectangle { anchors.fill: parent; radius: 36; color: Theme.tile.grey }
                        Image {
                            id: bigFace
                            anchors.fill: parent; visible: false; cache: false
                            source: Sys.exists(Sys.home() + "/.face.icon") ? "file://" + Sys.home() + "/.face.icon?v=" + Sys.faceRevision : ""
                            fillMode: Image.PreserveAspectCrop; sourceSize.width: 192
                        }
                        Rectangle { id: bigMask; anchors.fill: parent; radius: 36; visible: false; antialiasing: true }
                        GE.OpacityMask { anchors.fill: parent; source: bigFace; maskSource: bigMask; visible: bigFace.status === Image.Ready }
                        // «Editar» al pasar el puntero, como en macOS
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: 22; radius: 0; color: Qt.rgba(0, 0, 0, 0.55)
                            visible: bigMa.containsMouse && bigFace.status === Image.Ready
                            Txt { anchors.centerIn: parent; text: "Editar"; color: "white"; font.pixelSize: 11 }
                            layer.enabled: true
                        }
                        MouseArea {
                            id: bigMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: if (bigFace.status === Image.Ready) cropper.edit(Sys.home() + "/.face.icon")
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Txt { text: Sys.user(); font.pixelSize: 17; font.weight: Font.DemiBold }
                        Txt { Layout.fillWidth: true; text: "Se ve en la pantalla de bloqueo y en la de inicio de sesión"; color: Theme.secondary; font.pixelSize: Theme.smallSize; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                    MacButton { text: "Elegir archivo…"; onClicked: picker.open() }
                }
                // imágenes para elegir: las de Plasma y la de Vitrum (si existe)
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: {
                            const own = Sys.exists(Sys.home() + "/.local/share/vitrum/avatar.png") ? [Sys.home() + "/.local/share/vitrum/avatar.png"] : []
                            const dir = "/usr/share/plasma/avatars"
                            return own.concat(Sys.listDir(dir, ["*.png", "*.jpg"]))   // rutas completas
                        }
                        Item {
                            required property string modelData
                            width: 48; height: 48
                            Image { id: av; anchors.fill: parent; visible: false; source: "file://" + modelData; sourceSize.width: 96; fillMode: Image.PreserveAspectCrop }
                            Rectangle { id: avMask; anchors.fill: parent; radius: 24; visible: false; antialiasing: true }
                            GE.OpacityMask { anchors.fill: parent; source: av; maskSource: avMask }
                            Rectangle {
                                anchors.fill: parent; anchors.margins: -3; radius: 27
                                color: "transparent"; border.width: 2
                                border.color: avMa.containsMouse ? Theme.accent : "transparent"
                            }
                            MouseArea { id: avMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Sys.setUserPicture(parent.modelData) }
                        }
                    }
                }
            }
        }
    }
    QQC.Popup {
        id: cropper
        property string src: ""
        property size orig: Qt.size(1, 1)
        readonly property int view: 260
        // escala de la vista: «cubrir» el círculo × ampliación
        readonly property real base: view / Math.max(1, Math.min(orig.width, orig.height))
        property real zoom: 1
        readonly property real s: base * zoom
        function edit(path) {
            src = path.indexOf("file://") === 0 ? path : "file://" + path
            orig = Sys.imageSize(src)
            zoom = 1
            photo.x = (view - orig.width * s) / 2
            photo.y = (view - orig.height * s) / 2
            open()
        }
        // la imagen siempre cubre el círculo
        function clamp() {
            photo.x = Math.min(0, Math.max(view - orig.width * s, photo.x))
            photo.y = Math.min(0, Math.max(view - orig.height * s, photo.y))
        }
        onZoomChanged: {
            // amplía alrededor del centro del círculo
            const cx = (view / 2 - photo.x) / (photo.width || 1), cy = (view / 2 - photo.y) / (photo.height || 1)
            photo.width = orig.width * s; photo.height = orig.height * s
            photo.x = view / 2 - cx * photo.width; photo.y = view / 2 - cy * photo.height
            clamp()
        }
        parent: QQC.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        padding: 20
        background: Rectangle { radius: 14; color: Theme.windowBg; border.width: 0.5; border.color: Theme.sidebarEdge }
        contentItem: ColumnLayout {
            spacing: 14
            Txt { text: "Ajustar la foto"; font.weight: Font.DemiBold; font.pixelSize: 15 }
            Item {
                Layout.alignment: Qt.AlignHCenter
                width: cropper.view; height: cropper.view
                clip: true
                Rectangle { anchors.fill: parent; color: "#111" }
                Image {
                    id: photo
                    source: cropper.visible ? cropper.src : ""
                    width: cropper.orig.width * cropper.s
                    height: cropper.orig.height * cropper.s
                    sourceSize.width: Math.min(2048, cropper.orig.width)
                    autoTransform: true
                    smooth: true; mipmap: true
                    cache: false
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: photo
                    onPositionChanged: if (pressed) cropper.clamp()
                    onReleased: cropper.clamp()
                    onWheel: (w) => cropper.zoom = Math.max(1, Math.min(5, cropper.zoom * (w.angleDelta.y > 0 ? 1.08 : 1 / 1.08)))
                }
                // fuera del círculo, oscurecido: así se verá la foto
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const g = getContext("2d")
                        g.reset()
                        g.fillStyle = Qt.rgba(0, 0, 0, 0.55)
                        g.fillRect(0, 0, width, height)
                        g.globalCompositeOperation = "destination-out"
                        g.beginPath(); g.arc(width / 2, height / 2, width / 2 - 1, 0, 2 * Math.PI); g.fill()
                        g.globalCompositeOperation = "source-over"
                        g.strokeStyle = Qt.rgba(1, 1, 1, 0.8); g.lineWidth = 1.5
                        g.beginPath(); g.arc(width / 2, height / 2, width / 2 - 1, 0, 2 * Math.PI); g.stroke()
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Txt { text: "−"; color: Theme.secondary; font.pixelSize: 16 }
                MacSlider {
                    width: 200; from: 1; to: 5; stepSize: 0.01
                    value: cropper.zoom
                    onMoved: (v) => cropper.zoom = v
                    onReleased: (v) => cropper.zoom = v
                }
                Txt { text: "+"; color: Theme.secondary; font.pixelSize: 16 }
            }
            Txt { Layout.alignment: Qt.AlignHCenter; text: "Arrastra para encuadrar"; color: Theme.secondary; font.pixelSize: Theme.smallSize }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                MacButton { text: "Cancelar"; onClicked: cropper.close() }
                MacButton {
                    text: "Guardar"; primary: true
                    onClicked: {
                        Sys.setUserPicture(cropper.src, -photo.x / cropper.s, -photo.y / cropper.s, cropper.view / cropper.s)
                        cropper.close()
                    }
                }
            }
        }
    }
    FileDialog {
        id: picker
        title: "Elegir foto de la cuenta"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.bmp)"]
        currentFolder: "file://" + Sys.home() + "/Imágenes"
        onAccepted: cropper.edit(String(selectedFile))
    }

    Card {
        Repeater {
            model: p.d.rows
            RowItem {
                title: modelData.t
                subtitle: modelData.s || ""
                tileIcon: modelData.icon || ""
                tileColor: Theme.tile.blue
                chevron: !!(modelData.k || modelData.go || modelData.run)
                onClicked: modelData.k ? p.kcm(modelData.k) : modelData.go ? p.open(modelData.go) : Sys.detached(modelData.run)
                MacSwitch {
                    visible: !!modelData.sw
                    checked: modelData.sw ? Sys.readConf(modelData.sw[0], modelData.sw[1], modelData.sw[2], modelData.sw[4]) === modelData.sw[3] : false
                    onToggled: (v) => Sys.writeConf(modelData.sw[0], modelData.sw[1], modelData.sw[2], v ? modelData.sw[3] : modelData.sw[4])
                }
                MacPopup {
                    visible: !!modelData.popup
                    model: modelData.popup ? modelData.popup[4] : []
                    currentIndex: modelData.popup ? p.idx(modelData.popup[3], Sys.readConf(modelData.popup[0], modelData.popup[1], modelData.popup[2], modelData.popup[5])) : 0
                    onActivated: (i) => Sys.writeConf(modelData.popup[0], modelData.popup[1], modelData.popup[2], modelData.popup[3][i])
                }
            }
        }
    }
}
