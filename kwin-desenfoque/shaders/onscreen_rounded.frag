#extension GL_OES_standard_derivatives : enable

#include "vitrumcolor.glsl"

#include "sdf.glsl"

uniform sampler2D texUnit;
uniform mat4 colorMatrix;
uniform float offset;
uniform vec2 halfpixel;
uniform vec4 box;
uniform vec4 cornerRadius;
uniform float opacity;

varying vec2 uv;
varying vec2 vertex;

// Esquina continua de macOS (superelipse p=2,8 con alcance r×1,4737) cuando radius < 0;
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

void main(void)
{
    vec4 sum = texture2D(texUnit, uv + vec2(-halfpixel.x * 2.0, 0.0) * offset);
    sum += texture2D(texUnit, uv + vec2(-halfpixel.x, halfpixel.y) * offset) * 2.0;
    sum += texture2D(texUnit, uv + vec2(0.0, halfpixel.y * 2.0) * offset);
    sum += texture2D(texUnit, uv + vec2(halfpixel.x, halfpixel.y) * offset) * 2.0;
    sum += texture2D(texUnit, uv + vec2(halfpixel.x * 2.0, 0.0) * offset);
    sum += texture2D(texUnit, uv + vec2(halfpixel.x, -halfpixel.y) * offset) * 2.0;
    sum += texture2D(texUnit, uv + vec2(0.0, -halfpixel.y * 2.0) * offset);
    sum += texture2D(texUnit, uv + vec2(-halfpixel.x, -halfpixel.y) * offset) * 2.0;

    float f = vitrumSdfBox(vertex, box.xy, box.zw, cornerRadius);
    float df = fwidth(f);
    float cover = 1.0 - clamp(0.5 + f / df, 0.0, 1.0);
    // franja [0, 1] px dentro del borde: el filo blanco, con cobertura exacta por píxel
    float inner = 1.0 - clamp(0.5 + (f + 1.0) / df, 0.0, 1.0);
    float band = cover > 0.0 ? (cover - inner) / cover : 0.0;
    vec4 fragColor = vitrumMaterial(sum / 12.0, colorMatrix, edgeLight * band) * opacity * cover;

    gl_FragColor = fragColor;
}
