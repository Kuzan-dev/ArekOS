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
print("parche aplicado en", dst)
