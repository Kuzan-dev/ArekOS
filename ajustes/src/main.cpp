// Ajustes del Sistema de Vitrum: interfaz QML estilo macOS sobre la configuración real de KDE.
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QApplication>
#include <algorithm>
#include <QPainterPath>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegion>
#include <QScreen>
#include <QStandardPaths>

#include <KApplicationTrader>
#include <KConfig>
#include <KConfigGroup>
#include <KWindowEffects>

#include "kcmview.h"

class Sys : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    // Ejecuta y espera (para comandos rápidos). Devuelve stdout.
    Q_INVOKABLE QString run(const QString &prog, const QStringList &args = {}, int timeoutMs = 4000)
    {
        QProcess p;
        p.start(prog, args);
        if (!p.waitForFinished(timeoutMs)) {
            p.kill();
            p.waitForFinished(500);
            return {};
        }
        return QString::fromUtf8(p.readAllStandardOutput());
    }

    // Ejecuta sin bloquear; el resultado llega por la señal finished(tag, ...).
    Q_INVOKABLE void runAsync(const QString &tag, const QString &prog, const QStringList &args = {})
    {
        auto *p = new QProcess(this);
        connect(p, &QProcess::finished, this, [this, p, tag](int code, QProcess::ExitStatus) {
            Q_EMIT finished(tag, code, QString::fromUtf8(p->readAllStandardOutput()), QString::fromUtf8(p->readAllStandardError()));
            p->deleteLater();
        });
        connect(p, &QProcess::errorOccurred, this, [this, p, tag](QProcess::ProcessError) {
            if (p->state() == QProcess::NotRunning) {
                Q_EMIT finished(tag, -1, {}, p->errorString());
                p->deleteLater();
            }
        });
        p->start(prog, args);
    }

    Q_INVOKABLE void detached(const QString &prog, const QStringList &args = {})
    {
        QProcess::startDetached(prog, args);
    }

    // Lee/escribe la configuración de KDE (kdeglobals, kwinrc...). groups admite anidados: ["Containments","25"].
    Q_INVOKABLE QString readConf(const QString &file, const QStringList &groups, const QString &key, const QString &def = {})
    {
        KConfig cfg(file, KConfig::NoGlobals);
        return group(cfg, groups).readEntry(key, def);
    }

    Q_INVOKABLE void writeConf(const QString &file, const QStringList &groups, const QString &key, const QString &value)
    {
        KConfig cfg(file, KConfig::NoGlobals);
        auto g = group(cfg, groups);
        g.writeEntry(key, value, KConfig::Notify);
        cfg.sync();
    }

    Q_INVOKABLE void deleteConf(const QString &file, const QStringList &groups, const QString &key)
    {
        KConfig cfg(file, KConfig::NoGlobals);
        auto g = group(cfg, groups);
        g.deleteEntry(key, KConfig::Notify);
        cfg.sync();
    }

    Q_INVOKABLE QStringList confGroups(const QString &file, const QStringList &groups = {})
    {
        KConfig cfg(file, KConfig::NoGlobals);
        return groups.isEmpty() ? cfg.groupList() : group(cfg, groups).groupList();
    }

    // Información de un archivo para la vista rápida
    Q_INVOKABLE QVariantMap fileInfo(const QString &path) const
    {
        const QFileInfo fi(path);
        const auto mime = QMimeDatabase().mimeTypeForFile(fi);
        return {{QStringLiteral("name"), fi.fileName()}, {QStringLiteral("size"), fi.size()}, {QStringLiteral("dir"), fi.isDir()},
                {QStringLiteral("mime"), mime.name()}, {QStringLiteral("mimeComment"), mime.comment()}, {QStringLiteral("icon"), mime.iconName()},
                {QStringLiteral("modified"), fi.lastModified()}, {QStringLiteral("exists"), fi.exists()}};
    }

    Q_INVOKABLE QString readText(const QString &path, int maxBytes = 200000) const
    {
        QFile f(path);
        return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.read(maxBytes)) : QString();
    }

    Q_INVOKABLE QString home() const { return QDir::homePath(); }
    Q_INVOKABLE QString user() const { return qEnvironmentVariable("USER"); }
    Q_INVOKABLE bool exists(const QString &path) const { return QFile::exists(path); }

    Q_INVOKABLE QString readFile(const QString &path) const
    {
        QFile f(path);
        return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
    }

    Q_INVOKABLE QStringList listDir(const QString &path, const QStringList &filters = {}, bool dirs = false) const
    {
        QDir d(path);
        const auto entries = d.entryInfoList(filters, (dirs ? QDir::Dirs : QDir::Files) | QDir::NoDotAndDotDot, QDir::Name);
        QStringList out;
        for (const auto &e : entries)
            out << e.absoluteFilePath();
        return out;
    }

    // Apps instaladas (para Launchpad): nombre, icono, id del .desktop, categorías y palabras clave.
    Q_INVOKABLE QVariantList apps() const
    {
        const auto services = KApplicationTrader::query([](const KService::Ptr &s) {
            return !s->noDisplay() && s->showOnCurrentPlatform() && !s->exec().isEmpty();
        });
        QVariantList out;
        for (const auto &s : services) {
            out << QVariantMap{{QStringLiteral("name"), s->name()}, {QStringLiteral("icon"), s->icon()},
                               {QStringLiteral("id"), s->storageId()}, {QStringLiteral("generic"), s->genericName()},
                               {QStringLiteral("keywords"), s->keywords().join(QLatin1Char(' '))},
                               {QStringLiteral("categories"), s->categories().join(QLatin1Char(';'))}};
        }
        std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
        });
        return out;
    }

    Q_INVOKABLE QVariantMap appInfo(const QString &storageId) const
    {
        const auto s = KService::serviceByStorageId(storageId);
        if (!s)
            return {};
        return {{QStringLiteral("name"), s->name()}, {QStringLiteral("icon"), s->icon()}, {QStringLiteral("id"), s->storageId()}};
    }

    Q_INVOKABLE void launch(const QString &storageId)
    {
        const auto s = KService::serviceByStorageId(storageId);
        QString id = s ? s->desktopEntryName() : storageId;
        if (id.endsWith(QStringLiteral(".desktop"), Qt::CaseInsensitive))
            id.chop(8);
        if (KService::serviceByDesktopName(id)) {
            QProcess::startDetached(QStringLiteral("kstart"), {QStringLiteral("--application"), id});
        } else if (s && !s->entryPath().isEmpty()) {
            QProcess::startDetached(QStringLiteral("kioclient"), {QStringLiteral("exec"), s->entryPath()});
        } else {
            QProcess::startDetached(QStringLiteral("kstart"), {QStringLiteral("--application"), id});
        }
    }

    // Zona que recibe clics (el resto de la ventana deja pasar el ratón a lo que hay debajo).
    Q_INVOKABLE void setInputRegion(QQuickWindow *w, qreal x, qreal y, qreal width, qreal height)
    {
        if (w) {
            w->setMask(QRegion(QRect(qRound(x), qRound(y), qRound(width), qRound(height))));
            w->update();
        }
    }

    Q_INVOKABLE void clearBlur(QQuickWindow *w)
    {
        if (w)
            KWindowEffects::enableBlurBehind(w, false);
    }

    // pantalla activa según KWin (la del puntero): Spotlight y Launchpad se abren en ella
    Q_INVOKABLE QString activeOutput() const
    {
        QDBusMessage m = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
                                                        QStringLiteral("org.kde.KWin"), QStringLiteral("activeOutputName"));
        const QDBusMessage r = QDBusConnection::sessionBus().call(m, QDBus::Block, 300);
        return r.type() == QDBusMessage::ReplyMessage && !r.arguments().isEmpty() ? r.arguments().first().toString() : QString();
    }

    // módulo de KDE que se puede mostrar dentro de Ajustes (QML) o que necesita su propia ventana (QWidget)
    Q_INVOKABLE bool kcmEmbeddable(const QString &id) const { return KcmView::isEmbeddable(id); }

    Q_INVOKABLE bool trashFull() const
    {
        return !QDir(QDir::homePath() + QStringLiteral("/.local/share/Trash/files")).isEmpty(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden);
    }

    // Material de macOS con KWin: desenfoque detrás de un rectángulo redondeado y, encima, la matriz de
    // color del efecto de contraste (saturación × intensidad, y el contraste aporta el gris añadido).
    // Medido en macOS: saturación 1,57 / 1,68, brillo 0,56 / 0,59 y +0,09 / +0,36 de gris (oscuro / claro).
    Q_INVOKABLE void setBlur(QQuickWindow *w, qreal x, qreal y, qreal width, qreal height, qreal radius,
                             qreal contrast = 1.0, qreal intensity = 1.0, qreal saturation = 1.5)
    {
        if (!w)
            return;
        // Con el desenfoque de Vitrum (kwin-desenfoque) las esquinas las recorta KWin con una máscara suavizada de
        // esquina continua (superelipse p≈2,8, como en macOS) a partir del radio que la ventana indica en su título
        // ("…#r19"); la región solo tiene que cubrir esa forma con la misma curva continua:
        const qreal r = std::max<qreal>(0, radius - 1.5);
        const qreal cr = std::min(r * 1.36, std::min(width, height) / 2.0);
        const qreal cp = cr * 0.30;
        QPainterPath path;
        path.moveTo(x + cr, y);
        path.lineTo(x + width - cr, y);
        path.cubicTo(x + width - cp, y, x + width, y + cp, x + width, y + cr);
        path.lineTo(x + width, y + height - cr);
        path.cubicTo(x + width, y + height - cp, x + width - cp, y + height, x + width - cr, y + height);
        path.lineTo(x + cr, y + height);
        path.cubicTo(x + cp, y + height, x, y + height - cp, x, y + height - cr);
        path.lineTo(x, y + cr);
        path.cubicTo(x, y + cp, x + cp, y, x + cr, y);
        path.closeSubpath();
        const QRegion region(path.toFillPolygon().toPolygon());
        KWindowEffects::enableBlurBehind(w, true, region);
        // KWin 6.6 aplica esta matriz (saturación y contraste) dentro del propio desenfoque, con la misma región
        KWindowEffects::enableBackgroundContrast(w, true, contrast, intensity, saturation, region);
        w->update(); // KWin aplica la región en el siguiente fotograma: forzarlo
    }

Q_SIGNALS:
    void finished(const QString &tag, int code, const QString &out, const QString &err);

private:
    static KConfigGroup group(KConfig &cfg, const QStringList &groups)
    {
        KConfigGroup g = cfg.group(groups.value(0));
        for (int i = 1; i < groups.size(); ++i)
            g = g.group(groups.at(i));
        return g;
    }
};

// org.vitrum.Shell: los atajos (Super, Super+S…) y la barra de menús piden abrir Launchpad o Spotlight.
class ShellBus : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.vitrum.Shell")
public:
    using QObject::QObject;
public Q_SLOTS:
    Q_SCRIPTABLE void ToggleLaunchpad() { Q_EMIT launchpadRequested(); }
    Q_SCRIPTABLE void ToggleSpotlight() { Q_EMIT spotlightRequested(); }
    Q_SCRIPTABLE void ToggleControlCenter() { Q_EMIT controlCenterRequested(); }
    // abre el Centro de Control en una vista ("", wifi, bt, sonido, concentracion); pruebas sin ratón
    Q_SCRIPTABLE void ControlCenterView(const QString &view) { Q_EMIT controlCenterViewRequested(view); }
    Q_SCRIPTABLE void Search(const QString &text) { Q_EMIT searchRequested(text); }
    // muestra la vista previa de ventanas de una app del Dock (pruebas sin ratón)
    Q_SCRIPTABLE void PreviewApp(const QString &appId) { Q_EMIT previewRequested(appId); }
Q_SIGNALS:
    void previewRequested(const QString &appId);
    void controlCenterRequested();
    void controlCenterViewRequested(const QString &view);
    void searchRequested(const QString &text);
    void launchpadRequested();
    void spotlightRequested();
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv); // QApplication: algunos módulos de KDE (Estilo de las apps…) usan widgets
    app.setApplicationName(QStringLiteral("vitrum-ajustes"));
    app.setApplicationDisplayName(QStringLiteral("Ajustes del Sistema"));
    app.setDesktopFileName(QStringLiteral("org.vitrum.ajustes"));
    app.setOrganizationName(QStringLiteral("vitrum"));

    Sys sys;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Sys"), &sys);
    qmlRegisterType<KcmView>("Vitrum", 1, 0, "KcmView");

    // vitrum-ajustes [página]                  → Ajustes del Sistema
    // vitrum-ajustes --vista-rapida <archivo>  → Vista rápida (Quick Look)
    // vitrum-ajustes --shell                   → escritorio: dock, Launchpad y Spotlight
    const QStringList args = app.arguments().mid(1);
    const bool quickLook = args.value(0) == QStringLiteral("--vista-rapida");
    const bool shell = args.value(0) == QStringLiteral("--shell");
    ShellBus bus;
    if (shell) {
        auto session = QDBusConnection::sessionBus();
        if (session.interface()->isServiceRegistered(QStringLiteral("org.vitrum.Shell")))
            return 0; // ya hay uno en marcha
        session.registerObject(QStringLiteral("/Shell"), &bus, QDBusConnection::ExportScriptableSlots);
        app.setQuitOnLastWindowClosed(false);
        engine.rootContext()->setContextProperty(QStringLiteral("ShellBus"), &bus);
    }
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"), quickLook ? QString() : args.value(0));
    engine.rootContext()->setContextProperty(QStringLiteral("quickLookFile"), quickLook ? QFileInfo(args.value(1)).absoluteFilePath() : QString());

    const QString qmlDir = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("vitrum-ajustes/qml"), QStandardPaths::LocateDirectory);
    engine.addImportPath(qmlDir);
    const QString file = shell ? QStringLiteral("/Shell.qml") : quickLook ? QStringLiteral("/VistaRapida.qml") : QStringLiteral("/Main.qml");
    engine.load(QUrl::fromLocalFile(qmlDir + file));
    if (engine.rootObjects().isEmpty())
        return 1;
    // el nombre se publica con la interfaz ya cargada: una llamada que arranca el dock (Super…) no se pierde
    if (shell && !QDBusConnection::sessionBus().registerService(QStringLiteral("org.vitrum.Shell")))
        return 0;
    return app.exec();
}

#include "main.moc"
