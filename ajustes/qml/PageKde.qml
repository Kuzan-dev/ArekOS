import QtQuick
import QtQuick.Layouts
import Vitrum

// Opciones completas de KDE: el módulo nativo (KCM) dentro de la ventana, con Aplicar/Revertir/Restablecer
// abajo, como las hojas de opciones de Ajustes del Sistema de macOS.
Item {
    id: p
    property string pageId: ""
    readonly property string kcmId: pageId.indexOf("kde:") === 0 ? pageId.slice(4) : pageId
    property string title: kcm.name || "Opciones de KDE"
    signal open(string id)

    KcmView {
        id: kcm
        module: p.kcmId
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: bar.top; leftMargin: 8; rightMargin: 8 }
        clip: true
    }
    Txt {
        visible: kcm.error !== ""
        anchors.centerIn: parent
        width: parent.width - 60
        wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
        text: kcm.error
        color: Theme.secondary
    }

    // Barra inferior: volver (subpáginas del módulo), Restablecer, Revertir y Aplicar
    Item {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: kcm.hasApply || kcm.hasDefaults || kcm.depth > 1 ? 44 : 0
        visible: height > 0
        Rectangle { width: parent.width; height: 1; color: Theme.separator }
        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 8
            MacButton { visible: kcm.depth > 1; text: "‹ Atrás"; onClicked: kcm.pop() }
            MacButton { visible: kcm.hasDefaults; text: "Restablecer"; opacity: kcm.representsDefaults ? 0.45 : 1; onClicked: if (!kcm.representsDefaults) kcm.defaults() }
            Item { Layout.fillWidth: true }
            MacButton { visible: kcm.hasApply; text: "Revertir"; opacity: kcm.needsSave ? 1 : 0.45; onClicked: if (kcm.needsSave) kcm.revert() }
            MacButton { visible: kcm.hasApply; text: "Aplicar"; primary: kcm.needsSave; opacity: kcm.needsSave ? 1 : 0.45; onClicked: if (kcm.needsSave) kcm.save() }
        }
    }
}
