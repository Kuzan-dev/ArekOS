#pragma once
// Muestra un módulo de configuración QML de KDE (KCM) dentro de Ajustes del Sistema, en vez de abrirlo
// en otra ventana con kcmshell6. Comparte el motor QML de la app y admite las subpáginas del módulo.

#include <QPointer>
#include <QQuickItem>

class KQuickConfigModule;

class KcmView : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QString module READ module WRITE setModule NOTIFY moduleChanged)
    Q_PROPERTY(QString name READ name NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY stateChanged)
    Q_PROPERTY(bool needsSave READ needsSave NOTIFY stateChanged)
    Q_PROPERTY(bool representsDefaults READ representsDefaults NOTIFY stateChanged)
    Q_PROPERTY(bool hasDefaults READ hasDefaults NOTIFY stateChanged)
    Q_PROPERTY(bool hasApply READ hasApply NOTIFY stateChanged)
    Q_PROPERTY(int depth READ depth NOTIFY stateChanged)

public:
    explicit KcmView(QQuickItem *parent = nullptr);
    ~KcmView() override;

    QString module() const { return m_module; }
    void setModule(const QString &id);
    QString name() const { return m_name; }
    QString error() const { return m_error; }
    bool loaded() const { return m_kcm != nullptr; }
    bool needsSave() const;
    bool representsDefaults() const;
    bool hasDefaults() const;
    bool hasApply() const;
    int depth() const { return int(m_pages.size()); }

    // ¿Es un módulo QML que se puede mostrar dentro de la ventana? (los de QWidget van en kcmshell6)
    Q_INVOKABLE static bool isEmbeddable(const QString &id);

    Q_INVOKABLE void save();
    Q_INVOKABLE void revert();
    Q_INVOKABLE void defaults();
    Q_INVOKABLE void pop();

Q_SIGNALS:
    void moduleChanged();
    void stateChanged();

protected:
    void componentComplete() override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    void load();
    void push(QQuickItem *page);
    void relayout();

    QString m_module, m_name, m_error;
    KQuickConfigModule *m_kcm = nullptr;
    QList<QPointer<QQuickItem>> m_pages;
};
