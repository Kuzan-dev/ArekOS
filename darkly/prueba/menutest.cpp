// Prueba sin pantalla del estilo Darkly: pinta un menú como el del escritorio y lo guarda en PNG (con alfa).
// Uso: menutest <esquema.colors> <salida.png>
#include <KColorScheme>
#include <KSharedConfig>
#include <QAction>
#include <QApplication>
#include <QMenu>
#include <QPixmap>
#include <QStyleFactory>

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    app.setStyle(QStyleFactory::create(QStringLiteral("Darkly")));
    app.setPalette(KColorScheme::createApplicationPalette(KSharedConfig::openConfig(QString::fromLocal8Bit(argv[1]))));
    QMenu menu;
    menu.addMenu(QStringLiteral("Crear nuevo"))->addAction(QStringLiteral("x"));
    auto *pegar = menu.addAction(QStringLiteral("Pegar"));
    pegar->setShortcut(QKeySequence(QStringLiteral("Ctrl+V")));
    pegar->setEnabled(false);
    auto *deshacer = menu.addAction(QStringLiteral("Deshacer"));
    deshacer->setShortcut(QKeySequence(QStringLiteral("Ctrl+Z")));
    deshacer->setEnabled(false);
    auto *rehacer = menu.addAction(QStringLiteral("Deshacer: Cambiar de nombre"));
    rehacer->setShortcut(QKeySequence(QStringLiteral("Ctrl+Z")));
    menu.addMenu(QStringLiteral("Iconos"))->addAction(QStringLiteral("x"));
    menu.addSeparator();
    menu.addAction(QStringLiteral("Entrar en el modo de edición"));
    menu.ensurePolished();
    menu.adjustSize();
    menu.show();
    app.processEvents();
    menu.grab().save(QString::fromLocal8Bit(argv[2]));
    return 0;
}
