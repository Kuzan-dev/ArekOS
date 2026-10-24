#!/usr/bin/env python3
"""Convierte src/plugins/blur de KWin en el "Desenfoque de Vitrum" (efecto externo).
Uso: parchear.py <carpeta blur de KWin> <destino>
Cada cambio comprueba que el código original sigue como se espera: si una versión nueva de KWin lo cambia,
el script falla (y se sigue usando el desenfoque de KDE) en vez de generar un efecto roto."""
import os, re, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
shutil.rmtree(dst, ignore_errors=True)
os.makedirs(dst)
for f in ("blur.cpp", "blur.h", "main.cpp", "blur.kcfg", "blurconfig.kcfgc"):
    shutil.copy(os.path.join(src, f), dst)
shutil.copytree(os.path.join(src, "shaders"), os.path.join(dst, "shaders"))
shutil.copy(os.path.join(src, "blur.qrc"), os.path.join(dst, "vitrumblur.qrc"))
here = os.path.dirname(os.path.abspath(__file__))
for f in ("CMakeLists.txt", "metadata.json"):
    shutil.copy(os.path.join(here, "..", f), dst)

def edit(name, fn):
    p = os.path.join(dst, name)
    s = open(p, encoding="utf-8").read()
    s2 = fn(s)
    open(p, "w", encoding="utf-8").write(s2)

def must(s, old, new, count=1):
    if old not in s:
        sys.exit(f"parchear: no se encontró:\n{old[:120]}")
    return s.replace(old, new, count)

# nombres propios (el desenfoque de KDE va dentro de libkwin con los mismos nombres)
def rename(s):
    for a, b in (("BlurEffectData", "VitrumBlurEffectData"), ("BlurRenderData", "VitrumBlurRenderData"),
                 ("BlurEffect", "VitrumBlurEffect"), ("BlurConfig", "VitrumBlurConfig")):
        s = re.sub(rf"\b{a}\b", b, s)
    return s
for f in ("blur.cpp", "blur.h", "main.cpp"):
    edit(f, rename)
edit("blurconfig.kcfgc", lambda s: must(s, "ClassName=BlurConfig", "ClassName=VitrumBlurConfig"))
edit("vitrumblur.qrc", lambda s: must(s, 'prefix="/effects/blur/"', 'prefix="/effects/vitrumblur/"'))
edit("main.cpp", lambda s: must(s, '"metadata.json.stripped"', '"metadata.json"'))

RADIUS_FN = '''// Vitrum: las superficies de vitrum-shell (Dock, Centro de Control, Spotlight…) no tienen decoración, así que KWin
// no conoce su radio de esquina y recortaba el desenfoque con la región en píxeles enteros (esquinas en escalera).
// Lo indican en su título: "vitrum-dock#r19" → radio 19. Con él se usa la máscara suavizada de KWin sobre el
// rectángulo de su región, igual que en las ventanas con decoración.
static qreal vitrumCornerRadius(const EffectWindow *w)
{
    const QString caption = w->caption();
    if (!caption.startsWith(QLatin1String("vitrum-"))) {
        return 0;
    }
    const int at = caption.indexOf(QLatin1String("#r"));
    return at < 0 ? 0 : caption.mid(at + 2).toDouble();
}

static QMatrix4x4 colorTransformMatrix('''

def blur_cpp(s):
    s = s.replace(":/effects/blur/shaders/", ":/effects/vitrumblur/shaders/")
    s = must(s, "Q_INIT_RESOURCE(blur);", "Q_INIT_RESOURCE(vitrumblur);")
    s = must(s, "static QMatrix4x4 colorTransformMatrix(", RADIUS_FN)
    s = must(s, "    if (const BorderRadius cornerRadius = w->window()->borderRadius(); !cornerRadius.isNull()) {",
             "    const qreal vitrumRadius = vitrumCornerRadius(w);\n"
             "    if (const BorderRadius cornerRadius = vitrumRadius > 0 ? BorderRadius(vitrumRadius) : w->window()->borderRadius(); !cornerRadius.isNull()) {")
    s = must(s, "        const QRectF transformedRect = QRectF{",
             "        const QRectF transformedRect = vitrumRadius > 0 ? QRectF(backgroundRect) : QRectF{")
    s = must(s, "        const BorderRadius nativeCornerRadius = cornerRadius.scaled(viewport.scale()).rounded();\n",
             "        BorderRadius nativeCornerRadius = cornerRadius.scaled(viewport.scale()).rounded();\n"
             "        if (vitrumRadius > 0) {\n"
             "            // señal para el shader: r < 0 indica esquina continua de macOS (superelipse p≈2,8)\n"
             "            const qreal nr = -std::round(vitrumRadius * viewport.scale());\n"
             "            nativeCornerRadius = BorderRadius(nr, nr, nr, nr);\n"
             "        }\n")
    return s
edit("blur.cpp", blur_cpp)

SQUIRCLE_SDF = '''// Esquina continua de macOS (superelipse p=2,8 con alcance r×1,4737) cuando radius < 0;
// para ventanas normales (radius >= 0) usa el arco circular de KWin.
float vitrumSdfBox(vec2 position, vec2 center, vec2 extents, vec4 radius)
{
    if (radius.x >= 0.0) {
        return sdfRoundedBox(position, center, extents, radius);
    }
    float r = -radius.x * 1.4737;
    vec2 q = abs(position - center) - extents + vec2(r);
    vec2 u = max(q, 0.0);
    float lp = pow(pow(u.x, 2.8) + pow(u.y, 2.8), 1.0 / 2.8);
    return min(max(q.x, q.y), 0.0) + lp - r;
}

void main(void)'''

for sh in ("shaders/onscreen_rounded.frag", "shaders/onscreen_rounded_core.frag"):
    edit(sh, lambda s: must(must(s, "void main(void)", SQUIRCLE_SDF),
                            "sdfRoundedBox(vertex, box.xy, box.zw, cornerRadius)",
                            "vitrumSdfBox(vertex, box.xy, box.zw, cornerRadius)"))
# Vitrum: material en el espacio de color de macOS (gamma) en cualquier salida, también HDR (ver
# shaders/vitrumcolor.glsl), con el tinte y el filo interior aplicados por el efecto en las superficies de vitrum-shell
shutil.copy(os.path.join(here, "..", "shaders", "vitrumcolor.glsl"), os.path.join(dst, "shaders"))
edit("vitrumblur.qrc", lambda s: must(s, "</qresource>\n</RCC>",
     '</qresource>\n<qresource prefix="/opengl/">\n  <file alias="vitrumcolor.glsl">shaders/vitrumcolor.glsl</file>\n</qresource>\n</RCC>'))

def blur_h(s):
    s = must(s, "    std::optional<QMatrix4x4> colorMatrix;\n};",
             "    std::optional<QMatrix4x4> colorMatrix;\n\n"
             "    /**\n     * Vitrum: intensidad del efecto de contraste (en vitrum-shell lleva el tinte del material, ver vitrumTint).\n     */\n"
             "    qreal intensity = 1.0;\n};")
    extra = "        int tfTypeLocation;\n        int tfLumLocation;\n        int toSrgbLocation;\n        int fromSrgbLocation;\n        int tintLocation;\n        int edgeLightLocation;\n"
    s = must(s, "        int halfpixelLocation;\n    } m_onscreenPass;", "        int halfpixelLocation;\n" + extra + "    } m_onscreenPass;")
    s = must(s, "        int opacityLocation;\n    } m_roundedOnscreenPass;", "        int opacityLocation;\n" + extra + "    } m_roundedOnscreenPass;")
    s = must(s, "#pragma once\n", "#pragma once\n\n#include <QVector2D>\n")
    return s
edit("blur.h", blur_h)

def blur_cpp_color(s):
    s = must(s, '#include "core/rendertarget.h"', '#include "core/colorspace.h"\n#include "core/rendertarget.h"')
    s = must(s, "    const qreal vitrumRadius = vitrumCornerRadius(w);\n",
             "    const qreal vitrumRadius = std::max(vitrumCornerRadius(w), materialRadius);\n")
    for p in ("m_onscreenPass", "m_roundedOnscreenPass"):
        old = f'        {p}.halfpixelLocation = {p}.shader->uniformLocation("halfpixel");\n'
        s = must(s, old, old + "".join(f'        {p}.{n}Location = {p}.shader->uniformLocation("{n}");\n'
                                       for n in ("tfType", "tfLum", "toSrgb", "fromSrgb", "tint", "edgeLight")))
        old = f'        {p}.shader->setUniform({p}.colorMatrixLocation, colorMatrix);\n'
        s = must(s, old, old + f'        {p}.shader->setUniform({p}.tfTypeLocation, int(tf.type));\n'
                               f'        {p}.shader->setUniform({p}.tfLumLocation, tfLum);\n'
                               f'        {p}.shader->setUniform({p}.toSrgbLocation, toSrgb);\n'
                               f'        {p}.shader->setUniform({p}.fromSrgbLocation, toSrgb.inverted());\n'
                               f'        {p}.shader->setUniform({p}.tintLocation, tint);\n'
                               f'        {p}.shader->setUniform({p}.edgeLightLocation, edgeLight);\n')
    s = must(s, "    std::optional<qreal> contrast;\n",
             "    std::optional<qreal> contrast;\n    qreal intensity = 1.0;\n")
    s = must(s, "            contrast = surface->contrast()->contrast();\n",
             "            contrast = surface->contrast()->contrast();\n            intensity = surface->contrast()->intensity();\n")
    s = must(s, "static QMatrix4x4 colorTransformMatrix(", TINT_FN + "static QMatrix4x4 colorTransformMatrix(")
    s = must(s, "        data.frame = frame;\n", "        data.frame = frame;\n        data.intensity = intensity;\n")
    s = must(s, "    const float modulation = opacity * opacity;\n",
             "    const float modulation = opacity * opacity;\n\n"
             "    // Vitrum: codificación de la salida, para aplicar el material en gamma 2,2 relativa al blanco de referencia\n"
             "    const auto &cd = renderTarget.colorDescription();\n"
             "    const TransferFunction tf = cd->transferFunction();\n"
             "    const QVector3D tfLum(tf.minLuminance, tf.maxLuminance, cd->referenceLuminance());\n"
             "    const QMatrix4x4 toSrgb = Colorimetry::BT709.fromXYZ() * cd->containerColorimetry().toXYZ();\n"
             "    qreal materialRadius;\n    QVector2D tint;\n    float edgeLight;\n    vitrumTint(w, blurInfo.intensity, materialRadius, tint, edgeLight);\n")
    return s

TINT_FN = """// Vitrum: las superficies de vitrum-shell (app vitrum-ajustes) llevan su material en la intensidad del efecto de
// contraste, que KWin no usa: intensidad = 10 × radio de esquina + tinte. El tinte (< 1 → capa negra de alfa
// 1 - tinte; > 1 → capa blanca de alfa tinte - 1) se aplica así en el mismo espacio de color que la saturación y el
// contraste, y no lo mezcla KWin en lineal (en HDR se veía grisáceo). Con él, el efecto pinta también el filo
// interior de 1 px (blanco al 17 %, medido en macOS), que en lineal se veía como una línea blanca brillante.
// El radio va aquí porque el dock y los paneles son superficies layer-shell, sin título donde indicarlo.
static void vitrumTint(const EffectWindow *w, qreal intensity, qreal &radius, QVector2D &tint, float &edgeLight)
{
    radius = 0;
    tint = QVector2D(1.0f, 0.0f);
    edgeLight = 0.0f;
    if (intensity < 10.0 || w->window()->resourceClass() != QLatin1String("vitrum-ajustes")) {
        return;
    }
    radius = std::floor(intensity / 10.0);
    const qreal t = intensity - radius * 10.0;
    if (t < 1.0) {
        tint = QVector2D(std::max(0.0, t), 0.0f);
    } else {
        const float a = std::min(1.0, t - 1.0);
        tint = QVector2D(1.0f - a, a);
    }
    edgeLight = 0.17f;
}

"""
edit("blur.cpp", blur_cpp_color)

def include_color(s):
    lines = s.split("\n"); i = 0
    while i < len(lines) and lines[i].startswith("#"):
        i += 1
    lines.insert(i, '\n#include "vitrumcolor.glsl"' if i else '#include "vitrumcolor.glsl"\n')
    return "\n".join(lines)
for sh in ("shaders/onscreen.frag", "shaders/onscreen_core.frag"):
    edit(sh, lambda s: must(include_color(s), "(sum / 12.0) * colorMatrix", "vitrumMaterial(sum / 12.0, colorMatrix, 0.0)"))
EDGE = """    float f = vitrumSdfBox(vertex, box.xy, box.zw, cornerRadius);
    float df = fwidth(f);
    float cover = 1.0 - clamp(0.5 + f / df, 0.0, 1.0);
    // franja [0, 1] px dentro del borde: el filo blanco, con cobertura exacta por píxel
    float inner = 1.0 - clamp(0.5 + (f + 1.0) / df, 0.0, 1.0);
    float band = cover > 0.0 ? (cover - inner) / cover : 0.0;
    {out} = vitrumMaterial(sum / 12.0, colorMatrix, edgeLight * band) * opacity * cover;"""
for sh, out in (("shaders/onscreen_rounded.frag", "vec4 fragColor"), ("shaders/onscreen_rounded_core.frag", "fragColor")):
    old = f"""    {out} = (sum / 12.0) * colorMatrix * opacity;

    float f = vitrumSdfBox(vertex, box.xy, box.zw, cornerRadius);
    float df = fwidth(f);
    fragColor *= 1.0 - clamp(0.5 + f / df, 0.0, 1.0);"""
    edit(sh, lambda s, old=old, out=out: must(include_color(s), old, EDGE.replace("{out}", out)))
# desenfoque en el espacio de trabajo: la primera pasada de reducción convierte cada muestra desde la salida
def downsample(s, tex):
    s = include_color(s)
    s = must(s, "uniform float offset;\n", "uniform float offset;\n// 1 en la primera pasada: convierte de la codificación de la salida al espacio de trabajo\nuniform float toWork;\n")
    s = must(s, "void main(void)\n",
             f"vec4 fetch(vec2 p)\n{{\n    vec4 c = {tex}(texUnit, p);\n    return toWork > 0.5 ? vitrumToWork(c) : c;\n}}\n\nvoid main(void)\n")
    body = s[s.index("void main(void)"):]
    s = s[:s.index("void main(void)")] + body.replace(f"{tex}(texUnit, ", "fetch(")
    return s
edit("shaders/downsample.frag", lambda s: downsample(s, "texture2D"))
edit("shaders/downsample_core.frag", lambda s: downsample(s, "texture"))

def blur_cpp_downsample(s):
    p = "m_downsamplePass"
    old = f'        {p}.halfpixelLocation = {p}.shader->uniformLocation("halfpixel");\n'
    s = must(s, old, old + "".join(f'        {p}.{n}Location = {p}.shader->uniformLocation("{n}");\n'
                                   for n in ("tfType", "tfLum", "toSrgb", "fromSrgb", "toWork")))
    s = must(s, f"        {p}.shader->setUniform({p}.offsetLocation, float(m_offset));\n",
             f"        {p}.shader->setUniform({p}.offsetLocation, float(m_offset));\n"
             f"        {{\n"
             f"            // Vitrum: la primera pasada pasa el fondo al espacio de trabajo (ver shaders/vitrumcolor.glsl)\n"
             f"            const auto &cd = renderTarget.colorDescription();\n"
             f"            const TransferFunction tf = cd->transferFunction();\n"
             f"            {p}.shader->setUniform({p}.tfTypeLocation, int(tf.type));\n"
             f"            {p}.shader->setUniform({p}.tfLumLocation, QVector3D(tf.minLuminance, tf.maxLuminance, cd->referenceLuminance()));\n"
             f"            const QMatrix4x4 toSrgb = Colorimetry::BT709.fromXYZ() * cd->containerColorimetry().toXYZ();\n"
             f"            {p}.shader->setUniform({p}.toSrgbLocation, toSrgb);\n"
             f"            {p}.shader->setUniform({p}.fromSrgbLocation, toSrgb.inverted());\n"
             f"        }}\n")
    s = must(s, f"            {p}.shader->setUniform({p}.halfpixelLocation, halfpixel);\n",
             f"            {p}.shader->setUniform({p}.halfpixelLocation, halfpixel);\n"
             f"            {p}.shader->setUniform({p}.toWorkLocation, i == 1 ? 1.0f : 0.0f);\n")
    return s
edit("blur.cpp", blur_cpp_downsample)
edit("blur.h", lambda s: must(s, "        int halfpixelLocation;\n    } m_downsamplePass;",
                              "        int halfpixelLocation;\n        int tfTypeLocation;\n        int tfLumLocation;\n        int toSrgbLocation;\n        int fromSrgbLocation;\n        int toWorkLocation;\n    } m_downsamplePass;"))
# compensación HDR del material (solo superficies de vitrum-shell en salidas HDR)
def blur_cpp_hdr(s):
    for p in ("m_onscreenPass", "m_roundedOnscreenPass"):
        old = f'        {p}.edgeLightLocation = {p}.shader->uniformLocation("edgeLight");\n'
        s = must(s, old, old + f'        {p}.blackLiftLocation = {p}.shader->uniformLocation("blackLift");\n')
        old = f'        {p}.shader->setUniform({p}.edgeLightLocation, edgeLight);\n'
        s = must(s, old, old + f'        {p}.shader->setUniform({p}.blackLiftLocation, blackLift);\n')
    s = must(s, "    vitrumTint(w, blurInfo.intensity, materialRadius, tint, edgeLight);\n",
             "    vitrumTint(w, blurInfo.intensity, materialRadius, tint, edgeLight);\n"
             "    // salida HDR: hay margen por encima del blanco de referencia (o es PQ)\n"
             "    const bool hdrOutput = tf.type == TransferFunction::PerceptualQuantizer || cd->referenceLuminance() < tf.maxLuminance * 0.95;\n"
             "    const float blackLift = (materialRadius > 0 && hdrOutput) ? float(m_hdrBlackLift) : 0.0f;\n")
    s = must(s, "    m_noiseStrength = VitrumBlurConfig::noiseStrength();\n",
             "    m_noiseStrength = VitrumBlurConfig::noiseStrength();\n"
             "    m_hdrBlackLift = std::clamp(KSharedConfig::openConfig(QStringLiteral(\"kwinrc\"))->group(QStringLiteral(\"Effect-vitrumblur\")).readEntry(\"HdrBlackLift\", 0.03), 0.0, 0.3);\n")
    return s
edit("blur.cpp", blur_cpp_hdr)
edit("blur.h", lambda s: must(must(must(s,
    "        int edgeLightLocation;\n    } m_onscreenPass;", "        int edgeLightLocation;\n        int blackLiftLocation;\n    } m_onscreenPass;"),
    "        int edgeLightLocation;\n    } m_roundedOnscreenPass;", "        int edgeLightLocation;\n        int blackLiftLocation;\n    } m_roundedOnscreenPass;"),
    "    int m_noiseStrength;\n", "    int m_noiseStrength;\n    qreal m_hdrBlackLift = 0.03;\n"))
print("parche aplicado en", dst)
