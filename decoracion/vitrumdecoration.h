#pragma once
// Decoración de ventanas de Vitrum: barra de título y semáforos con las medidas de macOS Monterey/Sequoia.

#include <QVariant>

#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButton>
#include <KDecoration3/DecorationButtonGroup>

#include <memory>

namespace Vitrum
{

class Decoration : public KDecoration3::Decoration
{
    Q_OBJECT
public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = {});
    ~Decoration() override;

    bool init() override;
    void paint(QPainter *painter, const QRectF &repaintRegion) override;

    // macOS muestra los símbolos de los tres botones a la vez al pasar el ratón por cualquiera
    bool groupHovered() const { return m_groupHovered; }
    void setGroupHovered(bool hovered);
    void refreshGroupHover();
    bool isDark() const;
    bool hidesTitleBar() const { return m_noTitleBar; }

private:
    void recalculate();
    void updateShadow();
    QColor titleBarColor() const;
    QColor fontColor() const;

    KDecoration3::DecorationButtonGroup *m_buttons = nullptr;
    bool m_groupHovered = false;
    bool m_noTitleBar = false;
};

class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT
public:
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);
    explicit Button(QObject *parent, const QVariantList &args);
    static Button *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);
    void paint(QPainter *painter, const QRectF &repaintRegion) override;
};

} // namespace Vitrum
