/*
    Pantalla de inicio de sesión de Vitrum, al estilo de macOS Sequoia: fecha y hora grandes arriba; abajo los
    usuarios (foto y nombre), el campo de contraseña bajo el elegido y los botones Reposo, Reiniciar y Apagar.
    Sustituye solo la interfaz (Main.qml) de plasma-login-greeter: la autenticación, los modelos de usuarios y
    sesiones y el fondo desenfocado son los de Plasma Login.
*/
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

import org.kde.plasma.login as PlasmaLogin

Item {
    id: root
    anchors.fill: parent
    readonly property real s: Math.max(0.75, height / 1080)
    readonly property string font: "Inter"
    readonly property bool active: PlasmaLogin.GreeterState.activeWindow === Window.window
    readonly property bool prompt: PlasmaLogin.GreeterState.beyondUserLimit
                                   || PlasmaLogin.GreeterState.loginState === PlasmaLogin.GreeterState.LoginState.UserPrompt
    property int sel: PlasmaLogin.GreeterState.userListIndex
    // macOS: primero la fila de usuarios; al elegir uno, los demás se desvanecen, el elegido se desliza al centro
    // y aparece su contraseña (con una sola cuenta se elige directamente)
    readonly property int userCount: PlasmaLogin.UserModel.count
    property bool picked: userCount <= 1
    readonly property bool askPassword: root.prompt || root.picked
    function pick(i) {
        PlasmaLogin.GreeterState.activateWindow(root.Window.window)
        root.sel = i
        root.picked = true
        password.text = ""
        password.forceActiveFocus()
    }
    function unpick() {
        if (root.userCount <= 1) return
        root.picked = false
        password.text = ""
        root.message = ""
        chooser.forceActiveFocus()
    }
    property string message: ""
    property bool busy: false

    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    KeyboardIndicator.KeyState { id: capsLock; key: Qt.Key_CapsLock }

    // nombre de usuario de una fila del modelo
    function userAt(i, role) {
        const m = PlasmaLogin.UserModel
        return m.data(m.index(i, 0), role)
    }
    function login() {
        const user = root.prompt ? userField.text : userAt(root.sel, PlasmaLogin.UserModel.NameRole)
        if (!user || busy) return
        busy = true
        root.message = ""
        PlasmaLogin.GreeterState.handleLoginRequest(user, password.text, session.currentSessionType, session.currentSessionFileName)
    }
    Connections {
        target: PlasmaLogin.Authenticator
        function onLoginFailed() {
            root.busy = false
            root.message = "Contraseña incorrecta"
            password.text = ""
            shake.restart()
            password.forceActiveFocus()
            messageClear.restart()
        }
        function onLoginSucceeded() { content.opacity = 0 }
    }
    Timer { id: messageClear; interval: 4000; onTriggered: root.message = "" }

    // la contraseña se comparte con el estado del greeter (impide que se oculte mientras se escribe)
    Binding { target: PlasmaLogin.GreeterState; property: "userListPassword"; value: password.text }

    Connections {
        target: greeterEventFilter
        function onKeyPressed() { Qt.callLater(() => PlasmaLogin.GreeterState.activateWindow(root.Window.window)) }
        function onEscapeKeyPressed() {
            if (root.picked && root.userCount > 1) { root.unpick(); return }
            PlasmaLogin.GreeterState.timeoutWindow(root.Window.window)
            password.text = ""
        }
    }
    Connections {
        target: PlasmaLogin.GreeterState
        function onActiveWindowChanged() {
            if (root.active) Qt.callLater(() => (root.prompt && !userField.text ? userField : root.picked ? password : chooser).forceActiveFocus())
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.active ? Qt.ArrowCursor : Qt.BlankCursor
        onPressed: PlasmaLogin.GreeterState.activateWindow(Window.window)
        onPositionChanged: PlasmaLogin.GreeterState.activateWindow(Window.window)
    }

    Item {
        id: content
        anchors.fill: parent
        Behavior on opacity { NumberAnimation { duration: 300 } }

        // ── Fecha y hora ──
        Column {
            id: clock
            visible: PlasmaLogin.Settings.showClock
            anchors.horizontalCenter: parent.horizontalCenter
            y: 50 * root.s
            spacing: -10 * root.s
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: { const t = clock.now.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM"); return t.charAt(0).toUpperCase() + t.slice(1) }
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: root.font; font.pixelSize: 23 * root.s; font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.now.toLocaleTimeString(Qt.locale(), "H:mm")
                color: Qt.rgba(1, 1, 1, 0.82)
                font.family: "Inter Display"; font.pixelSize: 118 * root.s; font.weight: Font.Bold
                font.letterSpacing: -3 * root.s
                renderType: Text.CurveRendering     // contornos exactos: sin bordes pixelados a ningún tamaño
            }
        }

        // ── Usuarios, contraseña y botones (abajo) ──
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40 * root.s
            spacing: 14 * root.s

            // fila de usuarios (como la ventana de inicio de sesión de macOS); con más de 7, nombre y contraseña
            Item {
                id: users
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.prompt
                readonly property real cell: 170 * root.s
                width: Math.max(1, root.userCount) * cell
                height: 64 * root.s + 8 * root.s + 20 * root.s
                // recibe el teclado mientras no hay usuario elegido: flechas para moverse, Intro o escribir para elegir
                Item {
                    id: chooser
                    focus: !root.picked && !root.prompt
                    Keys.onLeftPressed: root.sel = Math.max(0, root.sel - 1)
                    Keys.onRightPressed: root.sel = Math.min(root.userCount - 1, root.sel + 1)
                    Keys.onReturnPressed: root.pick(root.sel)
                    Keys.onEnterPressed: root.pick(root.sel)
                    Keys.onPressed: (e) => {
                        if (e.text && e.text.length === 1 && e.text >= " ") { root.pick(root.sel); password.insert(0, e.text); e.accepted = true }
                    }
                }
                Repeater {
                    model: PlasmaLogin.UserModel
                    delegate: Column {
                        id: u
                        required property int index
                        required property string name
                        required property string realName
                        required property string icon
                        readonly property bool chosen: index === root.sel
                        width: users.cell
                        spacing: 8 * root.s
                        x: root.picked && chosen ? (users.width - width) / 2 : index * users.cell
                        Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                        opacity: root.picked ? (chosen ? 1 : 0) : (chosen || !root.active ? 1 : 0.7)
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                        enabled: opacity > 0.5
                        Avatar {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 64 * root.s
                            source: u.icon
                            letter: (u.realName || u.name).charAt(0).toUpperCase()
                            // anillo de selección con el teclado (sin agrandar la foto)
                            Rectangle {
                                anchors.fill: parent; anchors.margins: -3 * root.s; radius: width / 2
                                color: "transparent"; border.width: 2 * root.s; border.color: Qt.rgba(1, 1, 1, 0.7)
                                visible: !root.picked && u.chosen && root.active && chooser.activeFocus
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                            text: u.realName || u.name
                            color: "white"
                            font.family: root.font; font.pixelSize: 15 * root.s; font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }
                        TapHandler { onTapped: root.picked && u.chosen ? password.forceActiveFocus() : root.pick(u.index) }
                    }
                }
            }

            // usuario por nombre (sin lista)
            Pill {
                id: userBox
                visible: root.prompt
                anchors.horizontalCenter: parent.horizontalCenter
                TextInput {
                    id: userField
                    anchors.fill: parent; anchors.leftMargin: 14 * root.s; anchors.rightMargin: 14 * root.s
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"; font.family: root.font; font.pixelSize: 13 * root.s
                    clip: true
                    KeyNavigation.tab: password
                    Keys.onReturnPressed: password.forceActiveFocus()
                    Text { visible: !userField.text; anchors.verticalCenter: parent.verticalCenter; text: "Nombre de usuario"; color: Qt.rgba(1, 1, 1, 0.62); font: userField.font }
                }
            }

            // contraseña: píldora translúcida bajo el usuario elegido
            Pill {
                id: passBox
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: root.active && root.askPassword ? 1 : 0
                enabled: opacity > 0.5
                Behavior on opacity { NumberAnimation { duration: 220 } }
                transform: Translate { id: shakeX }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shakeX; property: "x"; to: -12 * root.s; duration: 50 }
                    NumberAnimation { target: shakeX; property: "x"; to: 12 * root.s; duration: 80 }
                    NumberAnimation { target: shakeX; property: "x"; to: -8 * root.s; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: 8 * root.s; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 50 }
                }
                TextInput {
                    id: password
                    anchors.fill: parent; anchors.leftMargin: 14 * root.s; anchors.rightMargin: 34 * root.s
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password; passwordCharacter: "●"
                    color: "white"; selectionColor: Qt.rgba(1, 1, 1, 0.35)
                    font.family: root.font; font.pixelSize: 13 * root.s; font.letterSpacing: 1.5 * root.s
                    enabled: !root.busy
                    focus: root.askPassword
                    clip: true
                    Keys.onReturnPressed: root.login()
                    Keys.onEnterPressed: root.login()
                    Text { visible: !password.text; anchors.verticalCenter: parent.verticalCenter; text: "Introducir contraseña"; color: Qt.rgba(1, 1, 1, 0.62); font.family: root.font; font.pixelSize: 13 * root.s }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 4 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20 * root.s; height: width; radius: width / 2
                    visible: password.text.length > 0 || capsLock.locked
                    color: password.text.length > 0 ? Qt.rgba(1, 1, 1, 0.30) : "transparent"
                    Text { anchors.centerIn: parent; text: password.text.length > 0 ? "→" : "⇪"; color: "white"; font.pixelSize: 12 * root.s; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; enabled: password.text.length > 0; onClicked: root.login() }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: root.active && root.askPassword ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
                text: root.message || (capsLock.locked ? "Bloq Mayús está activado" : (root.busy ? "Iniciando sesión…" : "Introduce la contraseña"))
                color: Qt.rgba(1, 1, 1, 0.75)
                font.family: root.font; font.pixelSize: 12 * root.s
            }

            Item { width: 1; height: 18 * root.s }

            // Reposo · Reiniciar · Apagar (y «Otro…» para escribir un usuario), como en macOS
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 42 * root.s
                RoundAction { label: "Reposo"; iconName: "system-suspend-symbolic"; shown: PlasmaLogin.SessionManagement.canSuspend
                    onActivated: { password.text = ""; PlasmaLogin.SessionManagement.suspend() } }
                RoundAction { label: "Reiniciar"; iconName: "system-reboot-symbolic"; shown: PlasmaLogin.SessionManagement.canReboot
                    onActivated: PlasmaLogin.SessionManagement.requestReboot(PlasmaLogin.SessionManagement.ConfirmationMode.Skip) }
                RoundAction { label: "Apagar"; iconName: "system-shutdown-symbolic"; shown: PlasmaLogin.SessionManagement.canShutdown
                    onActivated: PlasmaLogin.SessionManagement.requestShutdown(PlasmaLogin.SessionManagement.ConfirmationMode.Skip) }
                // con un usuario elegido, «Cancelar» vuelve a la fila (como en macOS); si no, «Otro…» pide nombre
                RoundAction { readonly property bool cancel: root.picked && root.userCount > 1 && !root.prompt
                    label: cancel ? "Cancelar" : root.prompt ? "Usuarios" : "Otro…"
                    iconName: cancel ? "window-close-symbolic" : root.prompt ? "system-users-symbolic" : "system-user-prompt-symbolic"
                    shown: !PlasmaLogin.GreeterState.beyondUserLimit
                    onActivated: {
                        if (cancel) root.unpick()
                        else PlasmaLogin.GreeterState.loginState = root.prompt ? PlasmaLogin.GreeterState.LoginState.UserList : PlasmaLogin.GreeterState.LoginState.UserPrompt
                    } }
            }
        }

        // abajo a la izquierda: sesión de escritorio (si hay más de una) y distribución de teclado
        Row {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 12 * root.s
            spacing: 6
            opacity: root.active ? 0.85 : 0
            KeyboardButton {}
            SessionButton { id: session }
        }
    }

    // ── Piezas ──
    component Pill: Rectangle {
        width: 200 * root.s; height: 28 * root.s; radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
    }
    component Avatar: Item {
        id: av
        property real size: 64
        property string source: ""
        property string letter: "?"
        width: size; height: size
        Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.25) }
        Image { id: img; anchors.fill: parent; source: av.source; fillMode: Image.PreserveAspectCrop; visible: false; sourceSize.width: 256 }
        Rectangle { id: imgMask; anchors.fill: parent; radius: width / 2; visible: false; antialiasing: true }
        GE.OpacityMask { anchors.fill: parent; source: img; maskSource: imgMask; visible: img.status === Image.Ready }
        Text {
            anchors.centerIn: parent; visible: img.status !== Image.Ready
            text: av.letter; color: "white"; font.family: root.font; font.pixelSize: av.size * 0.42; font.weight: Font.DemiBold
        }
    }
    component RoundAction: Column {
        id: ra
        property string label: ""
        property string iconName: ""
        property bool shown: true
        signal activated()
        visible: shown
        spacing: 6 * root.s
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 36 * root.s; height: width; radius: width / 2
            color: raMa.pressed ? Qt.rgba(1, 1, 1, 0.36) : (raMa.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.20))
            Kirigami.Icon { anchors.centerIn: parent; width: 18 * root.s; height: width; source: ra.iconName; isMask: true; color: "white" }
            MouseArea { id: raMa; anchors.fill: parent; hoverEnabled: true; onClicked: ra.activated() }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ra.label; color: Qt.rgba(1, 1, 1, 0.85)
            font.family: root.font; font.pixelSize: 12 * root.s
        }
    }
}
