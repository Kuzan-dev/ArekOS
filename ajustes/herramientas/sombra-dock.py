#!/usr/bin/env python3
"""Genera qml/sombra-dock.png: sombra del Dock medida en macOS Monterey (negro al 24 %, desenfoque gaussiano
σ = 19 px, sin desplazamiento, esquinas de 19 px), con el interior recortado para que no oscurezca el material.
Se usa como BorderImage de 9 partes (borde = P + R)."""
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

P, R, SIGMA, ALPHA, SS = 60, 19, 19.0, 0.24, 4      # margen, radio, σ, opacidad, supermuestreo
N = 2 * (P + R) + 240                                # rectángulo ancho: bordes rectos "infinitos"
def rounded_mask(n, inset, r, ss):
    m = n * ss
    yy, xx = np.mgrid[0:m, 0:m] / ss + 0.5 / ss
    x0, x1 = inset, n - inset
    cx = np.clip(xx, x0 + r, x1 - r); cy = np.clip(yy, x0 + r, x1 - r)
    inside = ((xx - cx) ** 2 + (yy - cy) ** 2 <= r * r) & (xx >= x0) & (xx <= x1) & (yy >= x0) & (yy <= x1)
    return inside.reshape(n, ss, n, ss).mean((1, 3))
rect = rounded_mask(N, P, R, SS)
shadow = gaussian_filter(rect, SIGMA, mode="constant") * ALPHA
shadow *= (1 - rect)                                  # nada dentro del Dock
img = np.zeros((N, N, 4), np.uint8)
img[..., 3] = np.clip(shadow * 255 + 0.5, 0, 255).astype(np.uint8)
Image.fromarray(img, "RGBA").save(sys.argv[1])
print("sombra", N, "px, borde", P + R)
