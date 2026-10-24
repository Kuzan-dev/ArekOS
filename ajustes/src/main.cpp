// Ajustes del Sistema de Vitrum: interfaz QML estilo macOS sobre la configuración real de KDE.
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageIOHandler>
#include <QImageReader>
#include <QUrl>
#include <QMenu>
#include <QDBusObjectPath>
#include <QDBusReply>
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

    // Menú nativo (QMenu): lo dibuja el estilo de las apps (Darkly), igual que el menú del escritorio y el de
    // cualquier app, translúcido y con las mismas esquinas. items: [{text, enabled, checked, separator}, …].
    // Se ancla al rectángulo (x, y, width, height) de la ventana w (p. ej. un icono del Dock) y se abre hacia
    // edge ("bottom": encima, centrado; "left"/"right": al lado; "": debajo). Con Wayland se usa el posicionador
    // de xdg_popup (relativo a la ventana padre): las superficies layer-shell no tienen posición global.
    // Devuelve el índice elegido o -1.
    Q_INVOKABLE int nativeMenu(QQuickWindow *w, qreal x, qreal y, qreal width, qreal height, const QVariantList &items,
                               const QString &edge = {})
    {
        QMenu menu;
        QList<QAction *> actions;
        for (const QVariant &v : items) {
            const QVariantMap it = v.toMap();
            if (it.value(QStringLiteral("separator")).toBool()) {
                actions << menu.addSeparator();
                continue;
            }
            QAction *a = menu.addAction(it.value(QStringLiteral("text")).toString());
            a->setEnabled(it.value(QStringLiteral("enabled"), true).toBool());
            if (it.contains(QStringLiteral("checked"))) {
                a->setCheckable(true);
                a->setChecked(it.value(QStringLiteral("checked")).toBool());
            }
            actions << a;
        }
        const QRect anchor = QRectF(x, y, std::max<qreal>(1, width), std::max<qreal>(1, height)).toRect();
        Qt::Edges side = Qt::BottomEdge;
        if (edge == QLatin1String("bottom"))
            side = Qt::TopEdge;
        else if (edge == QLatin1String("left"))
            side = Qt::RightEdge;
        else if (edge == QLatin1String("right"))
            side = Qt::LeftEdge;
        menu.winId(); // crea la ventana nativa para poder fijar su padre y el anclaje
        if (QWindow *mw = menu.windowHandle()) {
            if (w)
                mw->setTransientParent(w);
            mw->setProperty("_q_waylandPopupAnchorRect", anchor.adjusted(0, edge == QLatin1String("bottom") ? -8 : 0, 0, 0));
            mw->setProperty("_q_waylandPopupAnchor", QVariant::fromValue(side));
            mw->setProperty("_q_waylandPopupGravity", QVariant::fromValue(side));
            // xdg_positioner: deslizar en el eje del borde y voltear en el otro si no cabe
            const bool vertical = side == Qt::TopEdge || side == Qt::BottomEdge;
            mw->setProperty("_q_waylandPopupConstraintAdjustment", vertical ? (1u | 8u) : (2u | 4u));
        }
        const QPoint pos = w ? w->mapToGlobal(anchor.topLeft()) : anchor.topLeft();
        QAction *chosen = menu.exec(pos);
        return chosen ? int(actions.indexOf(chosen)) : -1;
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
    // ¿está cargado este efecto de KWin? (el material lo aplica el desenfoque de Vitrum solo si lo está)
    Q_INVOKABLE bool effectLoaded(const QString &name) const
    {
        QDBusMessage m = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
                                                        QStringLiteral("org.kde.kwin.Effects"), QStringLiteral("isEffectLoaded"));
        m << name;
        const QDBusMessage r = QDBusConnection::sessionBus().call(m, QDBus::Block, 500);
        return r.type() == QDBusMessage::ReplyMessage && !r.arguments().isEmpty() && r.arguments().constFirst().toBool();
    }

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

    // Foto de la cuenta: recorte cuadrado centrado a 512 px en ~/.face.icon y registrada en AccountsService (de
    // ahí la leen la pantalla de bloqueo y la de inicio de sesión). Cambiar la propia foto no pide contraseña.
    Q_PROPERTY(int faceRevision READ faceRevision NOTIFY faceChanged)
    int faceRevision() const { return m_faceRevision; }
    // tamaño real de una imagen (el editor de recorte trabaja sobre una vista reducida)
    Q_INVOKABLE QSize imageSize(const QString &source) const
    {
        QImageReader r(source.startsWith(QLatin1String("file://")) ? QUrl(source).toLocalFile() : source);
        QSize sz = r.size();
        if (r.transformation() & QImageIOHandler::TransformationRotate90)
            sz.transpose();   // foto girada por EXIF: se muestra con los lados cambiados
        return sz;
    }
    // (cropX, cropY, cropSide): cuadrado a recortar en píxeles de la imagen original (el editor de recorte de
    // Ajustes); sin él, el cuadrado centrado más grande
    Q_INVOKABLE bool setUserPicture(const QString &source, qreal cropX = -1, qreal cropY = -1, qreal cropSide = -1)
    {
        QString path = source;
        if (path.startsWith(QLatin1String("file://")))
            path = QUrl(path).toLocalFile();
        QImageReader reader(path);
        reader.setAutoTransform(true);   // fotos del móvil: orientación EXIF
        QImage img = reader.read();
        if (img.isNull())
            return false;
        QRect crop;
        if (cropSide > 0)
            crop = QRectF(cropX, cropY, cropSide, cropSide).toRect().intersected(img.rect());
        if (crop.width() < 8 || crop.height() < 8) {
            const int side = std::min(img.width(), img.height());
            crop = QRect((img.width() - side) / 2, (img.height() - side) / 2, side, side);
        }
        img = img.copy(crop).scaled(512, 512, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        const QString face = QDir::homePath() + QStringLiteral("/.face.icon");
        if (!img.save(face, "PNG"))
            return false;
        QDBusMessage find = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Accounts"), QStringLiteral("/org/freedesktop/Accounts"),
                                                           QStringLiteral("org.freedesktop.Accounts"), QStringLiteral("FindUserByName"));
        find << qEnvironmentVariable("USER");
        const QDBusReply<QDBusObjectPath> user = QDBusConnection::systemBus().call(find, QDBus::Block, 3000);
        if (user.isValid()) {
            QDBusMessage set = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Accounts"), user.value().path(),
                                                              QStringLiteral("org.freedesktop.Accounts.User"), QStringLiteral("SetIconFile"));
            set << face;
            QDBusConnection::systemBus().call(set, QDBus::Block, 5000);
        }
        ++m_faceRevision;
        Q_EMIT faceChanged();
        return true;
    }

    // avisa (serviceRegistered) cada vez que aparece ese nombre en el bus de sesión (p. ej. org.kde.spectacle)
    Q_INVOKABLE void watchService(const QString &name)
    {
        auto *w = new QDBusServiceWatcher(name, QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForRegistration, this);
        connect(w, &QDBusServiceWatcher::serviceRegistered, this, &Sys::serviceRegistered);
    }

Q_SIGNALS:
    void finished(const QString &tag, int code, const QString &out, const QString &err);
    void serviceRegistered(const QString &name);
    void faceChanged();

private:
    int m_faceRevision = 0;
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
