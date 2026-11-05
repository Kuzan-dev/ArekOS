import QtQuick
import org.kde.plasma.private.clipboard as Klipper

// Gestor del portapapeles (Klipper) sin icono, como el portapapeles de macOS.
// En Plasma 6 Klipper solo vive dentro del widget «Portapapeles» de la bandeja; la bandeja mínima
// de Vitrum lo quita y entonces lo copiado se pierde al cerrar la app de origen (Spectacle, etc.).
// Si el usuario activa el widget en Ajustes → Barra de menús, Klipper ya corre en plasmashell:
// aquí no se carga para no tener dos gestores peleándose por el portapapeles.
QtObject {
    id: root
    readonly property string rc: "plasma-org.kde.plasma.desktop-appletsrc"
    function trayHasClipboard() {
        for (const c of Sys.confGroups(rc, ["Containments"]))
            for (const a of Sys.confGroups(rc, ["Containments", c, "Applets"]))
                if (Sys.readConf(rc, ["Containments", c, "Applets", a], "plugin") === "org.kde.plasma.systemtray")
                    return Sys.readConf(rc, ["Containments", c, "Applets", a, "General"], "extraItems", "")
                        .split(",").indexOf("org.kde.plasma.clipboard") >= 0
        return false
    }
    property var history: null
    property var historyComponent: Component { Klipper.HistoryModel {} }
    Component.onCompleted: if (!trayHasClipboard()) history = historyComponent.createObject(root)
}
