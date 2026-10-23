#include "kcmview.h"

#include <KPluginMetaData>
#include <KQuickConfigModule>
#include <KQuickConfigModuleLoader>

#include <QQmlEngine>

#include <memory>

namespace
{
const QString KcmDir = QStringLiteral("plasma/kcms/systemsettings");
}

KcmView::KcmView(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, false);
}

KcmView::~KcmView()
{
    for (const auto &p : std::as_const(m_pages))
        if (p)
            p->setParentItem(nullptr);
    delete m_kcm;
}

bool KcmView::isEmbeddable(const QString &id)
{
    return KPluginMetaData::findPluginById(KcmDir, id).isValid();
}

void KcmView::setModule(const QString &id)
{
    if (id == m_module)
        return;
    m_module = id;
    Q_EMIT moduleChanged();
    if (isComponentComplete())
        load();
}

void KcmView::componentComplete()
{
    QQuickItem::componentComplete();
    load();
}

void KcmView::load()
{
    if (m_kcm || m_module.isEmpty())
        return;
    const KPluginMetaData md = KPluginMetaData::findPluginById(KcmDir, m_module);
    if (!md.isValid()) {
        m_error = QStringLiteral("No se encontró el módulo %1").arg(m_module);
        Q_EMIT stateChanged();
        return;
    }
    m_name = md.name();
    // el módulo usa el mismo motor QML que la app (sin adueñarse de él)
    QQmlEngine *engine = qmlEngine(this);
    std::shared_ptr<QQmlEngine> shared(engine, [](QQmlEngine *) {});
    auto result = KQuickConfigModuleLoader::loadModule(md, this, {}, shared);
    if (!result) {
        m_error = result.errorText;
        Q_EMIT stateChanged();
        return;
    }
    m_kcm = result.plugin;
    connect(m_kcm, &KQuickConfigModule::needsSaveChanged, this, &KcmView::stateChanged);
    connect(m_kcm, &KQuickConfigModule::representsDefaultsChanged, this, &KcmView::stateChanged);
    connect(m_kcm, &KQuickConfigModule::pagePushed, this, &KcmView::push);
    connect(m_kcm, &KQuickConfigModule::pageRemoved, this, [this]() {
        if (m_pages.size() > 1) {
            auto top = m_pages.takeLast();
            if (top)
                top->setVisible(false);
            relayout();
            Q_EMIT stateChanged();
        }
    });
    // primero la interfaz y luego la configuración, como Ajustes del Sistema de KDE: algunos módulos
    // (Idioma y región…) usan su motor QML en load() y fallan si aún no existe
    QQuickItem *ui = m_kcm->mainUi();
    if (!ui) {
        m_error = m_kcm->errorString();
        Q_EMIT stateChanged();
        return;
    }
    m_kcm->load();
    push(ui);
}

void KcmView::push(QQuickItem *page)
{
    if (!page)
        return;
    page->setParentItem(this);
    m_pages.append(page);
    relayout();
    Q_EMIT stateChanged();
}

void KcmView::pop()
{
    if (m_kcm && m_pages.size() > 1)
        m_kcm->pop(); // emite pageRemoved
}

void KcmView::relayout()
{
    for (int i = 0; i < m_pages.size(); ++i) {
        QQuickItem *p = m_pages.at(i);
        if (!p)
            continue;
        const bool top = i == m_pages.size() - 1;
        p->setVisible(top);
        if (top) {
            p->setPosition(QPointF(0, 0));
            p->setSize(size());
        }
    }
}

void KcmView::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    relayout();
}

bool KcmView::needsSave() const
{
    return m_kcm && m_kcm->needsSave();
}

bool KcmView::representsDefaults() const
{
    return !m_kcm || m_kcm->representsDefaults();
}

bool KcmView::hasDefaults() const
{
    return m_kcm && (m_kcm->buttons() & KAbstractConfigModule::Default);
}

bool KcmView::hasApply() const
{
    return m_kcm && (m_kcm->buttons() & KAbstractConfigModule::Apply);
}

void KcmView::save()
{
    if (m_kcm) {
        m_kcm->save();
        Q_EMIT stateChanged();
    }
}

void KcmView::revert()
{
    if (m_kcm) {
        m_kcm->load();
        Q_EMIT stateChanged();
    }
}

void KcmView::defaults()
{
    if (m_kcm) {
        m_kcm->defaults();
        Q_EMIT stateChanged();
    }
}
