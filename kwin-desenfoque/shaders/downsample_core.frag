#version 140

#include "vitrumcolor.glsl"

uniform sampler2D texUnit;
uniform float offset;
// 1 en la primera pasada: convierte de la codificación de la salida al espacio de trabajo
uniform float toWork;
uniform vec2 halfpixel;

in vec2 uv;

out vec4 fragColor;

vec4 fetch(vec2 p)
{
    vec4 c = texture(texUnit, p);
    return toWork > 0.5 ? vitrumToWork(c) : c;
}

void main(void)
{
    vec4 sum = fetch(uv) * 4.0;
    sum += fetch(uv - halfpixel.xy * offset);
    sum += fetch(uv + halfpixel.xy * offset);
    sum += fetch(uv + vec2(halfpixel.x, -halfpixel.y) * offset);
    sum += fetch(uv - vec2(halfpixel.x, -halfpixel.y) * offset);

    fragColor = sum / 8.0;
}
