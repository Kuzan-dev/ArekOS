// Vitrum: espacio de trabajo del material. macOS mezcla en sRGB codificado, y con él se midió el material
// (saturación, contraste y tinte). KWin, en cambio, compone en la codificación de la salida: gamma 2,2 en SDR,
// pero luz lineal (o PQ) en HDR, donde el mismo +gris del contraste o la misma capa negra aclaraban el dock
// (en lineal, +0,09 equivale a +34 % de brillo percibido). Aquí se pasa el desenfoque a gamma 2,2 relativo al
// blanco de referencia de la salida, se aplica el material y se vuelve a la codificación de la salida, así que
// el resultado es el mismo en cualquier pantalla y con cualquier fondo.
// tfType: 0 sRGB, 1 lineal, 2 PQ, 3 gamma 2,2, 4 BT.1886 (los de KWin::TransferFunction)
// tfLum: luminancia mínima, máxima (valor codificado 1) y de referencia (blanco SDR), en nits
uniform int tfType;
uniform vec3 tfLum;
// primarios de la salida → sRGB (BT.709) y vuelta, en luz lineal: con gama amplia KWin compone en BT.2020 y la
// saturación del material sobre esos números daba colores más apagados (lechosos) que en macOS
uniform mat4 toSrgb;
uniform mat4 fromSrgb;
// tinte del material en el espacio de trabajo: color * x + y (capa negra: (1 - a, 0); blanca: (1 - a, a))
uniform vec2 tint;
// filo interior de 1 px (blanco al 17 % en macOS), también en el espacio de trabajo
uniform float edgeLight;
// HDR: los paneles HDR muestran los grises oscuros más claros (negro elevado y blanco SDR alto) y el material se
// veía lechoso; en salidas HDR se baja su punto negro en esta cantidad (0 en SDR; kwinrc [Effect-vitrumblur])
uniform float blackLift;

vec3 vitrumDecode(vec3 e)
{
    vec3 n;
    if (tfType == 0) {
        n = mix(e / 12.92, pow(max((e + 0.055) / 1.055, 0.0), vec3(2.4)), step(0.04045, e));
    } else if (tfType == 1) {
        n = e;
    } else if (tfType == 2) {
        vec3 p = pow(max(e, 0.0), vec3(1.0 / 78.84375));
        n = pow(max(p - 0.8359375, 0.0) / (18.8515625 - 18.6875 * p), vec3(1.0 / 0.1593017578125));
    } else if (tfType == 4) {
        n = pow(max(e, 0.0), vec3(2.4));
    } else {
        n = pow(max(e, 0.0), vec3(2.2));
    }
    return n * (tfLum.y - tfLum.x) + tfLum.x;
}

vec3 vitrumEncode(vec3 nits)
{
    vec3 n = (nits - tfLum.x) / (tfLum.y - tfLum.x);
    if (tfType == 0) {
        n = clamp(n, 0.0, 1.0);
        return mix(n * 12.92, pow(n, vec3(1.0 / 2.4)) * 1.055 - 0.055, step(0.0031308, n));
    } else if (tfType == 1) {
        return n;
    } else if (tfType == 2) {
        vec3 p = pow(clamp(n, 0.0, 1.0), vec3(0.1593017578125));
        return pow((0.8359375 + 18.8515625 * p) / (1.0 + 18.6875 * p), vec3(78.84375));
    } else if (tfType == 4) {
        return pow(max(n, 0.0), vec3(1.0 / 2.4));
    }
    return pow(clamp(n, 0.0, 1.0), vec3(1.0 / 2.2));
}

// color premultiplicado de la salida → espacio de trabajo (premultiplicado). El desenfoque entero se hace ya en
// este espacio (primera pasada de reducción): en luz lineal las luces pequeñas se extendían y aclaraban el fondo
// desenfocado mucho más que en macOS.
vec4 vitrumToWork(vec4 c)
{
    float a = max(c.a, 1e-4);
    vec3 rel = (vitrumDecode(c.rgb / a) - tfLum.x) / (tfLum.z - tfLum.x);
    rel = max((toSrgb * vec4(rel, 1.0)).rgb, 0.0);
    return vec4(pow(rel, vec3(1.0 / 2.2)) * c.a, c.a);
}

// desenfoque en el espacio de trabajo → material aplicado, en la codificación de la salida; light: blanco a mezclar
vec4 vitrumMaterial(vec4 c, mat4 colorMatrix, float light)
{
    float a = max(c.a, 1e-4);
    vec4 w = vec4(c.rgb / a, 1.0) * colorMatrix;
    w.rgb = max(w.rgb * tint.x + tint.y, 0.0);
    w.rgb = mix(w.rgb, vec3(1.0), light);
    w.rgb = max(w.rgb - blackLift, 0.0) / (1.0 - blackLift);
    vec3 lin = (fromSrgb * vec4(pow(w.rgb, vec3(2.2)), 1.0)).rgb;
    vec3 nits = max(lin, 0.0) * (tfLum.z - tfLum.x) + tfLum.x;
    return vec4(vitrumEncode(nits) * c.a, c.a);
}
