// Decoración de ventanas de Vitrum. Medidas tomadas de macOS Monterey a 1x (Terminal/Finder):
// barra de título de 28 px; semáforos de 12 px con borde de 1 px más oscuro, 20 px entre centros,
// el primero a 14 px del borde izquierdo; esquinas de 10 px; símbolos ×, − y pantalla completa
// en los tres botones a la vez al pasar el ratón; botones grises en ventanas inactivas.
#include "vitrumdecoration.h"

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecorationShadow>
#include <KPluginFactory>

#include <QImage>
#include <QVariant>
#include <QPainter>
#include <QPainterPath>

#include <cmath>

K_PLUGIN_FACTORY_WITH_JSON(VitrumDecoFactory, "vitrum.json", registerPlugin<Vitrum::Decoration>(); registerPlugin<Vitrum::Button>();)

namespace Vitrum
{
namespace
{
constexpr qreal TitleBarHeight = 28;
constexpr qreal ButtonDiameter = 12;
constexpr qreal ButtonPitch = 20;       // distancia entre centros
constexpr qreal FirstButtonCenter = 14; // desde el borde izquierdo
constexpr qreal CornerRadius = 10;
constexpr qreal ResizeMargin = 6;       // zona invisible para redimensionar fuera de la ventana

struct LightColors {
    QColor fill, rim, glyph;
};

LightColors colorsFor(KDecoration3::DecorationButtonType type)
{
    switch (type) {
    case KDecoration3::DecorationButtonType::Close:
        return {QColor(0xFF, 0x5F, 0x57), QColor(0xE0, 0x44, 0x3E), QColor(0x4D, 0x00, 0x00)};
    case KDecoration3::DecorationButtonType::Minimize:
        return {QColor(0xFE, 0xBC, 0x2E), QColor(0xDE, 0xA1, 0x23), QColor(0x99, 0x57, 0x00)};
    default:
        return {QColor(0x28, 0xC8, 0x40), QColor(0x1A, 0xAB, 0x29), QColor(0x00, 0x65, 0x00)};
    }
}

// Desenfoque de caja (3 pasadas ≈ gaussiano) sobre una imagen premultiplicada
void boxBlur(QImage &img, int radius)
{
    if (radius < 1)
        return;
    const int w = img.width(), h = img.height();
    QList<int> tmp(w * h * 4);
    auto pass = [&](bool horizontal) {
        uchar *bits = img.bits();
        const int bpl = img.bytesPerLine();
        const int len = horizontal ? w : h, lines = horizontal ? h : w;
        for (int l = 0; l < lines; ++l) {
            for (int c = 0; c < 4; ++c) {
                int sum = 0;
                auto px = [&](int i) -> uchar & {
                    i = std::clamp(i, 0, len - 1);
                    return horizontal ? bits[l * bpl + i * 4 + c] : bits[i * bpl + l * 4 + c];
                };
                for (int i = -radius; i <= radius; ++i)
                    sum += px(i);
                for (int i = 0; i < len; ++i) {
                    tmp[(horizontal ? l * len + i : l * len + i) * 4 + c] = sum / (2 * radius + 1);
                    sum += px(i + radius + 1) - px(i - radius);
                }
            }
            for (int i = 0; i < len; ++i)
                for (int c = 0; c < 4; ++c) {
                    uchar &dst = horizontal ? bits[l * bpl + i * 4 + c] : bits[i * bpl + l * 4 + c];
                    dst = uchar(tmp[(l * len + i) * 4 + c]);
                }
        }
    };
    for (int k = 0; k < 3; ++k) {
        pass(true);
        pass(false);
    }
}
} // namespace

Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

Decoration::~Decoration() = default;

bool Decoration::init()
{
    auto w = window();
    // Ajustes del Sistema y Vista rápida de Vitrum dibujan sus propios semáforos (como las apps de macOS
    // con barra lateral a toda altura): sin barra de título, pero con esquinas y sombra
    m_noTitleBar = w->windowClass().contains(QLatin1String("vitrum"), Qt::CaseInsensitive);

    if (!m_noTitleBar)
        m_buttons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Left, this, &Button::create);

    auto refresh = [this]() {
        recalculate();
        update();
    };
    connect(w, &KDecoration3::DecoratedWindow::activeChanged, this, [this]() {
        updateShadow();
        update();
    });
    connect(w, &KDecoration3::DecoratedWindow::captionChanged, this, [this]() { update(); });
    connect(w, &KDecoration3::DecoratedWindow::widthChanged, this, refresh);
    connect(w, &KDecoration3::DecoratedWindow::maximizedChanged, this, refresh);
    connect(w, &KDecoration3::DecoratedWindow::paletteChanged, this, [this]() {
        updateShadow();
        update();
    });
    connect(settings().get(), &KDecoration3::DecorationSettings::fontChanged, this, refresh);
    recalculate();
    updateShadow();
    return true;
}

void Decoration::refreshGroupHover()
{
    bool any = false;
    if (m_buttons)
        for (auto *b : m_buttons->buttons())
            any = any || b->isHovered();
    setGroupHovered(any);
}

void Decoration::setGroupHovered(bool hovered)
{
    if (m_groupHovered == hovered)
        return;
    m_groupHovered = hovered;
    if (m_buttons)
        for (auto *b : m_buttons->buttons())
            b->update();
}

bool Decoration::isDark() const
{
    return titleBarColor().lightness() < 128;
}

QColor Decoration::titleBarColor() const
{
    // misma superficie que la ventana: barra de título y barra de herramientas unificadas, como en macOS
    return window()->palette().color(QPalette::Window);
}

QColor Decoration::fontColor() const
{
    const bool active = window()->isActive();
    if (isDark())
        return active ? QColor(0xDC, 0xDC, 0xDC) : QColor(0x70, 0x70, 0x70);
    return active ? QColor(0x4D, 0x4D, 0x4D) : QColor(0xB2, 0xB2, 0xB2);
}

void Decoration::recalculate()
{
    auto w = window();
    const bool maximized = w->isMaximized();
    const qreal top = m_noTitleBar ? 0 : TitleBarHeight;
    setBorders(QMarginsF(0, top, 0, 0));
    setResizeOnlyBorders(maximized ? QMarginsF() : QMarginsF(ResizeMargin, ResizeMargin, ResizeMargin, ResizeMargin));
    setTitleBar(QRectF(0, 0, w->width(), top));
    const qreal r = maximized ? 0 : CornerRadius;
    setBorderRadius(KDecoration3::BorderRadius(r, r, r, r));

    if (m_buttons) {
        m_buttons->setSpacing(0);
        for (auto *b : m_buttons->buttons())
            b->setGeometry(QRectF(0, 0, ButtonPitch, TitleBarHeight));
        m_buttons->setPos(QPointF(FirstButtonCenter - ButtonPitch / 2, 0));
    }
}

void Decoration::updateShadow()
{
    // Sombra de macOS: amplia y suave, desplazada hacia abajo; más tenue en ventanas inactivas
    const bool active = window()->isActive();
    const int spread = active ? 46 : 32;
    const qreal offsetY = active ? 16 : 10;
    const qreal alpha = active ? (isDark() ? 0.55 : 0.32) : (isDark() ? 0.40 : 0.20);
    const QSize box(2 * int(CornerRadius) + 2, 2 * int(CornerRadius) + 2);
    QImage img(box + QSize(2 * spread, 2 * spread), QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    const QRectF boxRect(spread, spread, box.width(), box.height());
    {
        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing);
        p.setPen(Qt::NoPen);
        p.setBrush(QColor(0, 0, 0, int(255 * alpha)));
        p.drawRoundedRect(boxRect.translated(0, offsetY).adjusted(4, 4, -4, -4), CornerRadius, CornerRadius);
    }
    boxBlur(img, spread / 3);
    {
        // contorno nítido muy fino alrededor de la ventana (separa ventanas claras sobre fondos claros)
        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing);
        p.setPen(QPen(QColor(0, 0, 0, isDark() ? 140 : 40), 1));
        p.setBrush(Qt::NoBrush);
        p.drawRoundedRect(boxRect.adjusted(-0.5, -0.5, 0.5, 0.5), CornerRadius + 0.5, CornerRadius + 0.5);
        // la sombra no debe verse a través de la propia ventana
        p.setCompositionMode(QPainter::CompositionMode_DestinationOut);
        p.setPen(Qt::NoPen);
        p.setBrush(Qt::black);
        p.drawRoundedRect(boxRect, CornerRadius, CornerRadius);
    }
    auto shadow = std::make_shared<KDecoration3::DecorationShadow>();
    shadow->setPadding(QMargins(spread, spread, spread, spread));
    shadow->setInnerShadowRect(QRect(img.rect().center(), QSize(1, 1)));
    shadow->setShadow(img);
    setShadow(shadow);

    // sin contorno de KWin: en sesión real lo pintaba blanco sólido (el filo oscuro de la sombra basta)
    setBorderOutline(KDecoration3::BorderOutline());
}

void Decoration::paint(QPainter *painter, const QRectF &repaintRegion)
{
    if (m_noTitleBar)
        return;
    auto w = window();
    const QRectF bar(0, 0, w->width(), TitleBarHeight);
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(Qt::NoPen);
    painter->setBrush(titleBarColor());
    const qreal r = w->isMaximized() ? 0 : CornerRadius;
    QPainterPath path;
    path.addRoundedRect(bar.adjusted(0, 0, 0, r), r, r);
    painter->setClipRect(bar);
    painter->drawPath(path);
    painter->setClipping(false);

    // título centrado en la ventana, seminegrita de 13 px
    QFont f = settings()->font();
    f.setPixelSize(13);
    f.setWeight(QFont::DemiBold);
    painter->setFont(f);
    painter->setPen(fontColor());
    const qreal side = FirstButtonCenter + 2 * ButtonPitch + 16;
    const QRectF textRect = bar.adjusted(side, 0, -side, 0);
    const QString caption = painter->fontMetrics().elidedText(w->caption(), Qt::ElideMiddle, int(textRect.width()));
    painter->drawText(textRect, Qt::AlignCenter, caption);
    painter->restore();

    if (m_buttons)
        m_buttons->paint(painter, repaintRegion);
}

Button::Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
{
    // al pasar de un botón a otro llegan "sale" y "entra" en cualquier orden: se mira el grupo entero
    connect(this, &KDecoration3::DecorationButton::hoveredChanged, this, [decoration]() { decoration->refreshGroupHover(); });
}

Button::Button(QObject *parent, const QVariantList &args)
    : Button(args.at(0).value<KDecoration3::DecorationButtonType>(), args.at(1).value<Decoration *>(), parent)
{
    setGeometry(QRectF(0, 0, ButtonPitch, TitleBarHeight));
}

Button *Button::create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent)
{
    auto d = qobject_cast<Decoration *>(decoration);
    if (!d)
        return nullptr;
    auto w = d->window();
    switch (type) {
    case KDecoration3::DecorationButtonType::Close: {
        auto b = new Button(type, d, parent);
        b->setVisible(w->isCloseable());
        connect(w, &KDecoration3::DecoratedWindow::closeableChanged, b, &Button::setVisible);
        return b;
    }
    case KDecoration3::DecorationButtonType::Minimize: {
        auto b = new Button(type, d, parent);
        b->setVisible(w->isMinimizeable());
        connect(w, &KDecoration3::DecoratedWindow::minimizeableChanged, b, &Button::setVisible);
        return b;
    }
    case KDecoration3::DecorationButtonType::Maximize: {
        auto b = new Button(type, d, parent);
        b->setVisible(w->isMaximizeable());
        connect(w, &KDecoration3::DecoratedWindow::maximizeableChanged, b, &Button::setVisible);
        return b;
    }
    default:
        return nullptr; // solo los tres semáforos, como en macOS
    }
}

void Button::paint(QPainter *painter, const QRectF &)
{
    if (!isVisible())
        return;
    auto d = qobject_cast<Decoration *>(decoration());
    if (!d)
        return;
    const QRectF g = geometry();
    const QPointF c = g.center();
    const QRectF circle(c.x() - ButtonDiameter / 2, c.y() - ButtonDiameter / 2, ButtonDiameter, ButtonDiameter);
    const bool active = d->window()->isActive();
    const bool showGlyph = d->groupHovered();
    LightColors col = colorsFor(type());
    if (!active && !showGlyph) {
        // ventana inactiva: botones grises
        col.fill = d->isDark() ? QColor(0x4E, 0x4E, 0x50) : QColor(0xCF, 0xCF, 0xCF);
        col.rim = d->isDark() ? QColor(0x3C, 0x3C, 0x3E) : QColor(0xB4, 0xB4, 0xB4);
    }
    if (isPressed()) {
        col.fill = col.fill.darker(118);
        col.rim = col.rim.darker(118);
    }

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(Qt::NoPen);
    painter->setBrush(col.rim);
    painter->drawEllipse(circle);
    painter->setBrush(col.fill);
    painter->drawEllipse(circle.adjusted(1, 1, -1, -1));

    if (showGlyph) {
        QColor g = col.glyph;
        g.setAlphaF(0.85);
        const qreal s = ButtonDiameter;
        const qreal x0 = circle.left(), y0 = circle.top();
        switch (type()) {
        case KDecoration3::DecorationButtonType::Close: {
            QPen pen(g, 1.2, Qt::SolidLine, Qt::RoundCap);
            painter->setPen(pen);
            const qreal a = s * 0.31, b = s * 0.69;
            painter->drawLine(QPointF(x0 + a, y0 + a), QPointF(x0 + b, y0 + b));
            painter->drawLine(QPointF(x0 + b, y0 + a), QPointF(x0 + a, y0 + b));
            break;
        }
        case KDecoration3::DecorationButtonType::Minimize: {
            painter->setBrush(g);
            painter->drawRoundedRect(QRectF(x0 + s * 0.22, c.y() - 0.6, s * 0.56, 1.2), 0.5, 0.5);
            break;
        }
        default: {
            // pantalla completa: dos triángulos enfrentados por la diagonal
            painter->setBrush(g);
            QPainterPath t1, t2;
            t1.moveTo(x0 + s * 0.27, y0 + s * 0.27);
            t1.lineTo(x0 + s * 0.65, y0 + s * 0.27);
            t1.lineTo(x0 + s * 0.27, y0 + s * 0.65);
            t1.closeSubpath();
            t2.moveTo(x0 + s * 0.73, y0 + s * 0.73);
            t2.lineTo(x0 + s * 0.35, y0 + s * 0.73);
            t2.lineTo(x0 + s * 0.73, y0 + s * 0.35);
            t2.closeSubpath();
            painter->drawPath(t1);
            painter->drawPath(t2);
            break;
        }
        }
    }
    painter->restore();
}

} // namespace Vitrum

#include "vitrumdecoration.moc"
