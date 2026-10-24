/*
    Pantalla de bloqueo de Vitrum, al estilo de macOS Sequoia: fecha y hora grandes arriba (con material
    vibrante), y abajo la foto del usuario, su nombre y el campo de contraseña en una píldora translúcida.
    La autenticación es la de KDE (objeto «authenticator» del bloqueador); si este archivo fallara al
    cargar, el bloqueador usa su pantalla de emergencia, así que nunca deja la sesión sin poder desbloquear.
*/
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import QtQuick.Layouts
import QtQuick.Controls as QQC

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.sessions
import org.kde.kscreenlocker as ScreenLocker

Item {
    id: ui
    readonly property real s: Math.max(0.75, height / 1080)         // medidas de macOS a 1080p
    readonly property string font: "Inter"
    property bool shown: false                                        // campo de contraseña visible
    property string message: ""

    // ── Autenticación (mismo flujo que la pantalla de KDE) ──────────────────────
    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) return                 // fallos de autenticadores no interactivos (huella…)
            ui.message = "Contraseña incorrecta"
            shake.restart()
            graceLock.restart()
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) Qt.quit()
            else noPassword.visible = true          // usuario sin contraseña: botón «Desbloquear»
        }
        function onInfoMessageChanged() { if (authenticator.infoMessage) ui.message = authenticator.infoMessage }
        function onErrorMessageChanged() { if (authenticator.errorMessage) ui.message = authenticator.errorMessage }
        function onPromptForSecretChanged() { password.forceActiveFocus() }
        // PAM impone una espera tras un fallo: no se puede volver a empezar antes (se quedaría atascado)
        function onLoginFailedDelayStarted(what, auth, uSecDelay) { graceLock.interval = Math.max(3000, uSecDelay / 1000 + 300); graceLock.restart() }
    }
    Connections {
        target: root
        function onClearPassword() { password.text = "" }
    }
    SessionManagement { id: sessionManagement }
    Connections {
        target: sessionManagement
        function onAboutToSuspend() { root.clearPassword() }
    }
    KeyboardIndicator.KeyState { id: capsLock; key: Qt.Key_CapsLock }

    // tras un fallo, PAM necesita volver a empezar (como la pantalla de KDE)
    Timer {
        id: graceLock
        interval: 3000
        onTriggered: { password.text = ""; authenticator.startAuthenticating(); messageClear.restart() }
    }
    Timer { id: messageClear; interval: 3000; onTriggered: ui.message = "" }
    // el campo se oculta tras 10 s sin actividad, como en macOS
    Timer { id: idle; interval: 10000; onTriggered: if (!password.text) ui.shown = false }
    function wake() {
        if (!ui.shown) { ui.shown = true; if (!graceLock.running) authenticator.startAuthenticating() }
        idle.restart()
        password.forceActiveFocus()
    }
    Component.onCompleted: { authenticator.startAuthenticating(); fadeIn.start() }

    // ── Fondo: el del escritorio, nítido como en Sequoia (solo se usa desenfocado dentro de la hora) ──
    ShaderEffectSource {
        id: wallSource
        anchors.fill: parent
        sourceItem: wallpaper
        hideSource: false
        visible: false
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        property point last: Qt.point(-1, -1)
        onPressed: ui.wake()
        onPositionChanged: (m) => {
            // un movimiento real del ratón (no el aviso inicial) despierta el campo
            if (last.x >= 0 && (Math.abs(m.x - last.x) > 3 || Math.abs(m.y - last.y) > 3)) ui.wake()
            last = Qt.point(m.x, m.y)
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        NumberAnimation on opacity { id: fadeIn; running: false; from: 0; to: 1; duration: 400 }

        // ── Fecha y hora (Sequoia: fecha seminegrita y hora grande en negrita, con material «vibrante»: el
        //    texto deja ver el fondo desenfocado y aclarado, y encima un blanco translúcido) ──
        Item {
            id: clockLayer
            anchors.fill: parent
            visible: false
            Column {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                y: 50 * ui.s
                spacing: -10 * ui.s
                property date now: new Date()
                Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: { const t = clock.now.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM"); return t.charAt(0).toUpperCase() + t.slice(1) }
                    color: "white"
                    font.family: ui.font; font.pixelSize: 23 * ui.s; font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: clock.now.toLocaleTimeString(Qt.locale(), "H:mm")
                    color: "white"
                    font.family: "Inter Display"; font.pixelSize: 118 * ui.s; font.weight: Font.Bold
                    font.letterSpacing: -3 * ui.s
                    renderType: Text.CurveRendering
                }
            }
        }
        ShaderEffectSource { id: clockMask; anchors.fill: parent; sourceItem: clockLayer; visible: false }
        // fondo desenfocado y aclarado (solo se ve dentro de las letras)
        MultiEffect {
            id: vibrant
            anchors.fill: parent
            visible: false
            source: wallSource
            autoPaddingEnabled: false
            blurEnabled: true; blurMax: 64; blur: 1.0
            brightness: 0.4; saturation: -0.35
        }
        // OpacityMask usa el alfa suavizado del texto (la máscara de MultiEffect corta por umbral: dientes de sierra)
        GE.OpacityMask { anchors.fill: parent; source: vibrant; maskSource: clockMask }
        ShaderEffectSource { anchors.fill: parent; sourceItem: clockLayer; opacity: 0.45 }

        // ── Reproduciendo (si hay música), sobre el usuario ──
        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: user.top; anchors.bottomMargin: 30 * ui.s
            width: 320 * ui.s
            active: config.showMediaControls !== false
            source: "MediaControls.qml"
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
        }

        // ── Usuario y contraseña (abajo, centrado) ──
        Column {
            id: user
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 84 * ui.s
            spacing: 10 * ui.s

            // foto del usuario: círculo con la imagen de la cuenta o su inicial
            Rectangle {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 60 * ui.s; height: width; radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.25)
                Image {
                    id: face
                    anchors.fill: parent
                    source: kscreenlocker_userImage ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    sourceSize.width: 256
                }
                Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; antialiasing: true }
                GE.OpacityMask {
                    anchors.fill: parent
                    source: face
                    maskSource: faceMask
                    visible: face.status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: (kscreenlocker_userName || "?").charAt(0).toUpperCase()
                    color: "white"; font.family: ui.font; font.pixelSize: 24 * ui.s; font.weight: Font.DemiBold
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: kscreenlocker_userName
                color: "white"
                font.family: ui.font; font.pixelSize: 15 * ui.s; font.weight: Font.DemiBold
            }

            // campo de contraseña: píldora translúcida; aparece al mover el ratón o pulsar una tecla
            Item {
                id: fieldBox
                anchors.horizontalCenter: parent.horizontalCenter
                width: 200 * ui.s; height: 28 * ui.s
                opacity: ui.shown ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
                transform: Translate { id: shakeX }
                SequentialAnimation {
                    id: shake
                    loops: 1
                    NumberAnimation { target: shakeX; property: "x"; to: -12 * ui.s; duration: 50 }
                    NumberAnimation { target: shakeX; property: "x"; to: 12 * ui.s; duration: 80 }
                    NumberAnimation { target: shakeX; property: "x"; to: -8 * ui.s; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: 8 * ui.s; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 50 }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.22)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                }
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 14 * ui.s
                    anchors.rightMargin: 34 * ui.s
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: "white"
                    selectionColor: Qt.rgba(1, 1, 1, 0.35)
                    font.family: ui.font; font.pixelSize: 13 * ui.s
                    font.letterSpacing: 1.5 * ui.s
                    enabled: !graceLock.running
                    focus: true
                    clip: true
                    onTextChanged: { ui.wake(); if (text) ui.message = "" }
                    Keys.onReturnPressed: send()
                    Keys.onEnterPressed: send()
                    Keys.onEscapePressed: { text = ""; ui.shown = false }
                    Keys.onPressed: (e) => { ui.wake(); e.accepted = false }
                    function send() { if (text.length) authenticator.respond(text) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !password.text
                        text: "Introducir contraseña"
                        color: Qt.rgba(1, 1, 1, 0.62)
                        font.family: ui.font; font.pixelSize: 13 * ui.s; font.letterSpacing: 0
                    }
                }
                // mayúsculas activadas (⇪) o botón de enviar (→), dentro del campo a la derecha
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 4 * ui.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20 * ui.s; height: width; radius: width / 2
                    visible: password.text.length > 0 || capsLock.locked
                    color: password.text.length > 0 ? Qt.rgba(1, 1, 1, 0.30) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: password.text.length > 0 ? "→" : "⇪"
                        color: "white"; font.pixelSize: 12 * ui.s; font.weight: Font.DemiBold
                    }
                    MouseArea { anchors.fill: parent; enabled: password.text.length > 0; onClicked: password.send() }
                }
            }
            // indicación bajo el campo (o el error de PAM)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: ui.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
                text: ui.message || (capsLock.locked ? "Bloq Mayús está activado" : "Introduce la contraseña")
                visible: ui.message || capsLock.locked || ui.shown
                color: Qt.rgba(1, 1, 1, 0.75)
                font.family: ui.font; font.pixelSize: 12 * ui.s
            }
            // cuentas sin contraseña: KDE ya autenticó, basta con confirmar
            Rectangle {
                id: noPassword
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                width: 140 * ui.s; height: 28 * ui.s; radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.22)
                Text { anchors.centerIn: parent; text: "Desbloquear"; color: "white"; font.family: ui.font; font.pixelSize: 13 * ui.s }
                MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
            }
        }

        // ── Abajo: cambiar de usuario, discreto ──
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 24 * ui.s
            spacing: 28 * ui.s
            opacity: ui.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Repeater {
                model: [
                    { t: "Cambiar de usuario", ok: sessionManagement.canSwitchUser, f: () => sessionManagement.switchUser() }
                ]
                Text {
                    required property var modelData
                    visible: modelData.ok
                    text: modelData.t
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.family: ui.font; font.pixelSize: 12 * ui.s
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.f() }
                }
            }
        }
    }
}
