import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuración del reloj (clic derecho → Configurar…): qué se ve en la barra de menús y con qué letra.
// «Negrita» del reloj de KDE (boldText) equivale aquí a grosor 700; al elegir un grosor se usa fontWeight.
KCM.SimpleKCM {
    property alias cfg_showDate: mostrarFecha.checked
    property string cfg_customDateFormat
    property string cfg_dateFormat
    property int cfg_use24hFormat
    property int cfg_showSeconds
    property string cfg_fontFamily
    property int cfg_fontSize
    property bool cfg_boldText
    property int cfg_fontWeight

    // formatos de fecha (el primero es el de macOS)
    readonly property var formatos: ["ddd d MMM", "d MMM", "dddd d 'de' MMMM", "dd/MM/yyyy", "yyyy-MM-dd"]
    // las mismas abreviaturas que el reloj (main.qml): «sáb», «nov.»
    function ejemplo(f) {
        const d = new Date()
        const dia = Qt.locale().dayName(d.getDay(), Locale.ShortFormat).replace(/\./g, "")
        const mes = Qt.locale().monthName(d.getMonth(), Locale.ShortFormat).replace(/\./g, "") + "."
        return Qt.locale().toString(d, f.replace(/dddd|ddd|MMMM|MMM/g, t => t === "ddd" ? "'" + dia + "'" : t === "MMM" ? "'" + mes + "'" : t))
    }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: mostrarFecha
            Kirigami.FormData.label: "Fecha:"
            text: "Mostrar la fecha junto a la hora"
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: "Formato de la fecha:"
            enabled: mostrarFecha.checked
            model: formatos.map(f => ejemplo(f))
            currentIndex: Math.max(0, formatos.indexOf(cfg_customDateFormat))
            onActivated: (i) => { cfg_customDateFormat = formatos[i]; cfg_dateFormat = "custom" }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            Kirigami.FormData.label: "Hora:"
            model: ["24 horas (" + Qt.formatTime(new Date(), "HH:mm") + ")", "12 horas (" + Qt.formatTime(new Date(), "h:mm") + (new Date().getHours() < 12 ? " a.m.)" : " p.m.)")]
            currentIndex: cfg_use24hFormat === 0 ? 1 : 0
            onActivated: (i) => cfg_use24hFormat = i === 1 ? 0 : 2
        }
        QQC2.CheckBox {
            text: "Mostrar los segundos"
            checked: cfg_showSeconds === 2
            onToggled: cfg_showSeconds = checked ? 2 : 0
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: fuente
            Kirigami.FormData.label: "Letra:"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            model: Qt.fontFamilies()
            currentIndex: Math.max(0, model.indexOf(cfg_fontFamily))
            onActivated: (i) => cfg_fontFamily = model[i]
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: "Tamaño:"
            from: 7; to: 16
            value: cfg_fontSize
            onValueModified: cfg_fontSize = value
        }
        QQC2.ComboBox {
            id: grosor
            Kirigami.FormData.label: "Grosor:"
            readonly property var pesos: [400, 500, 600, 700]
            model: ["Normal", "Media", "Seminegrita", "Negrita"]
            currentIndex: cfg_boldText ? 3 : Math.max(0, pesos.indexOf(cfg_fontWeight))
            onActivated: (i) => { cfg_fontWeight = pesos[i]; cfg_boldText = false }
        }
        QQC2.Button {
            text: "Como en macOS (Inter seminegrita, 10 pt)"
            icon.name: "edit-undo"
            onClicked: { cfg_fontFamily = "Inter"; cfg_fontSize = 10; cfg_boldText = false; cfg_fontWeight = 600
                         fuente.currentIndex = Math.max(0, fuente.model.indexOf("Inter")); grosor.currentIndex = 2 }
        }
    }
}
