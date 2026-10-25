"""
Core icon processing engine for Vitrum Icon Patcher.
Generates pixel-perfect macOS WhiteSur squircles from any icon.
"""

import os
import io
import re
import math
import base64
from pathlib import Path
from typing import Optional, Tuple
from PIL import Image

import gi
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf

from .constants import (
    SHADOW_BASE64,
    WHITESUR_SCALABLE_DIR,
    HICOLOR_SCALABLE_DIR,
    HICOLOR_512_DIR,
    HICOLOR_256_DIR,
    VITRUM_ICONOS_DIR,
    HOME
)


def find_icon_path(icon_name: str) -> Optional[str]:
    """Resolve an icon name or path to an actual file on disk."""
    if not icon_name:
        return None
        
    # If it's already an absolute or relative path that exists
    p = Path(icon_name).expanduser()
    if p.is_file():
        return str(p.resolve())

    # Common search roots
    search_dirs = [
        HOME / ".local/share/icons/WhiteSur/apps/scalable",
        HOME / ".local/share/icons/hicolor/512x512/apps",
        HOME / ".local/share/icons/hicolor/256x256/apps",
        HOME / ".local/share/icons/hicolor/scalable/apps",
        HOME / ".local/share/icons",
        Path("/usr/share/icons/hicolor/scalable/apps"),
        Path("/usr/share/icons/hicolor/512x512/apps"),
        Path("/usr/share/icons/hicolor/256x256/apps"),
        Path("/usr/share/icons/hicolor/128x128/apps"),
        Path("/usr/share/icons/hicolor/64x64/apps"),
        Path("/usr/share/icons/hicolor/48x48/apps"),
        Path("/usr/share/icons/hicolor/32x32/apps"),
        Path("/usr/share/pixmaps"),
        Path("/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps"),
        Path("/var/lib/flatpak/exports/share/icons/hicolor/512x512/apps"),
        Path("/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps"),
        HOME / ".local/share/flatpak/exports/share/icons/hicolor/scalable/apps",
        HOME / ".local/share/flatpak/exports/share/icons/hicolor/512x512/apps",
        HOME / ".local/share/flatpak/exports/share/icons/hicolor/256x256/apps",
    ]

    extensions = [".svg", ".png", ".webp", ".jpg", ".xpm"]

    # 1. Exact match with extensions
    for d in search_dirs:
        if not d.exists():
            continue
        for ext in extensions:
            candidate = d / f"{icon_name}{ext}"
            if candidate.is_file():
                return str(candidate.resolve())

    # 2. Check if icon_name already has extension
    for d in search_dirs:
        if not d.exists():
            continue
        candidate = d / icon_name
        if candidate.is_file():
            return str(candidate.resolve())

    # 3. Recursive search in ~/.local/share/icons and /usr/share/icons if not found
    for root_dir in [HOME / ".local/share/icons", Path("/usr/share/pixmaps")]:
        if not root_dir.exists():
            continue
        for ext in [".svg", ".png"]:
            matches = list(root_dir.glob(f"**/{icon_name}{ext}"))
            if matches:
                # Prefer larger or scalable
                matches.sort(key=lambda x: ("scalable" in str(x) or "512" in str(x)), reverse=True)
                return str(matches[0].resolve())

    return None


def is_icon_already_squircle(icon_path_or_name: str) -> bool:
    """Checks whether the icon already contains the authentic WhiteSur squircle/shadow."""
    if not icon_path_or_name:
        return False
        
    resolved = find_icon_path(icon_path_or_name)
    if not resolved:
        return False

    # Check if file is in WhiteSur/apps/scalable or vitrum-kde/iconos-apps
    if "WhiteSur/apps/scalable" in resolved or "vitrum-kde/iconos-apps" in resolved:
        return True

    # If it's an SVG, check for the squircle rect definition
    if resolved.endswith(".svg"):
        try:
            with open(resolved, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read(4096)
                if 'width="56"' in content and 'height="56"' in content and 'rx="13"' in content:
                    return True
                if 'rx="13"' in content and 'ry="13"' in content:
                    return True
        except Exception:
            pass

    return False


def rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{int(r):02x}{int(g):02x}{int(b):02x}"


def adjust_color(hex_color: str, factor: float) -> str:
    """Darken or lighten a hex color by a factor."""
    hex_color = hex_color.lstrip("#")
    if len(hex_color) != 6:
        return "#1f2336"
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    
    r = min(255, max(0, int(r * factor)))
    g = min(255, max(0, int(g * factor)))
    b = min(255, max(0, int(b * factor)))
    return rgb_to_hex(r, g, b)


def extract_dominant_colors(image: Image.Image) -> Tuple[str, str]:
    """Extract vibrant dominant color and build a complementary top/bottom gradient pair."""
    try:
        small = image.resize((80, 80), Image.Resampling.BOX).convert("RGBA")
        colors = small.getcolors(maxcolors=6400)
        if not colors:
            return ("#282c34", "#14161a")

        # Filter out transparent or very close to transparent pixels
        valid = []
        for count, (r, g, b, a) in colors:
            if a < 70:
                continue
            # Also calculate saturation and brightness
            max_c = max(r, g, b)
            min_c = min(r, g, b)
            delta = max_c - min_c
            sat = delta / max_c if max_c > 0 else 0
            val = max_c / 255.0
            
            # Weight saturated and medium-bright colors higher
            weight = count * (1.0 + sat * 2.0)
            valid.append((weight, (r, g, b)))

        if not valid:
            return ("#1f2336", "#0a0a0f")

        valid.sort(key=lambda x: x[0], reverse=True)
        top_r, top_g, top_b = valid[0][1]
        
        base_hex = rgb_to_hex(top_r, top_g, top_b)
        
        # Build gradient: top is slightly lighter, bottom is deeper
        top_gradient = adjust_color(base_hex, 1.15)
        bottom_gradient = adjust_color(base_hex, 0.65)
        
        return (top_gradient, bottom_gradient)
    except Exception:
        return ("#1f2336", "#0a0a0f")


def load_image_as_base64_png(image_path: str) -> Tuple[Optional[str], Optional[Image.Image]]:
    """Loads an image (SVG, PNG, JPG, WebP) and returns base64 data URI + PIL Image."""
    try:
        path = Path(image_path)
        if path.suffix.lower() == ".svg":
            # Render SVG to high-res pixbuf first
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path), 512, 512, True)
            buf = pixbuf.save_to_bufferv("png", [], [])
            png_bytes = buf[1]
            pil_img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
            b64 = "data:image/png;base64," + base64.b64encode(png_bytes).decode("ascii")
            return b64, pil_img
        else:
            pil_img = Image.open(image_path).convert("RGBA")
            buf = io.BytesIO()
            pil_img.save(buf, format="PNG")
            png_bytes = buf.getvalue()
            b64 = "data:image/png;base64," + base64.b64encode(png_bytes).decode("ascii")
            return b64, pil_img
    except Exception as e:
        print(f"Error loading image {image_path}: {e}")
        return None, None


def generate_squircle_svg(
    source_image_path: str,
    mode: str = "emblem",  # 'emblem' or 'mask'
    top_color: str = "auto",
    bottom_color: str = "auto",
    scale: float = 0.65,
    enable_shadow: bool = True
) -> str:
    """
    Generates the complete, authentic WhiteSur squircle SVG.
    """
    img_b64, pil_img = load_image_as_base64_png(source_image_path)
    if not img_b64 or pil_img is None:
        raise ValueError(f"No se pudo cargar la imagen fuente: {source_image_path}")

    # Determine colors
    if top_color == "auto" or bottom_color == "auto":
        auto_top, auto_bottom = extract_dominant_colors(pil_img)
        if top_color == "auto":
            top_color = auto_top
        if bottom_color == "auto":
            bottom_color = auto_bottom

    # Emblem calculations
    # Squircle center is at (32, 32), size is 56x56
    emblem_size = round(56 * scale, 2)
    emblem_x = round(32 - (emblem_size / 2.0), 2)
    emblem_y = round(32 - (emblem_size / 2.0), 2)
    shadow_y = round(emblem_y + 0.75, 2)

    shadow_filter = """
    <filter id="logo-shadow" width="1.4" height="1.4" x="-.2" y="-.2" style="color-interpolation-filters:sRGB">
      <feGaussianBlur stdDeviation="1.2"/>
    </filter>""" if enable_shadow else ""

    if mode == "mask":
        # Full-bleed mask mode:
        # Pre-mask the image directly with PIL so it does NOT rely on SVG clipPath,
        # which is unsupported or broken in Qt's QSvgRenderer / Kirigami / Launchpad.
        w, h = 512, 512
        resized = pil_img.resize((w, h), Image.Resampling.LANCZOS)
        mask = Image.new("L", (w, h), 0)
        from PIL import ImageDraw
        draw = ImageDraw.Draw(mask)
        # 13px radius on 56px squircle = ~119px on 512px canvas
        corner_r = int(w * (13.0 / 56.0))
        draw.rounded_rectangle([(0, 0), (w - 1, h - 1)], radius=corner_r, fill=255)
        
        masked_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        masked_img.paste(resized, (0, 0), mask=mask)
        
        buf = io.BytesIO()
        masked_img.save(buf, format="PNG")
        masked_b64 = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")

        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="64" height="64">
  <!-- Drop shadow WhiteSur -->
  <image xlink:href="{SHADOW_BASE64}" width="60.882" height="62.001" x="1.559" y="1.999" preserveAspectRatio="none"/>
  <!-- Pre-masked Squircle Artwork -->
  <image xlink:href="{masked_b64}" width="56" height="56" x="4" y="4" preserveAspectRatio="none"/>
</svg>"""
    else:
        # Emblem mode (with gradient background and centered logo)
        shadow_element = f"""
  <g transform="translate({emblem_x}, {shadow_y})" filter="url(#logo-shadow)" opacity="0.32">
    <image xlink:href="{img_b64}" width="{emblem_size}" height="{emblem_size}" preserveAspectRatio="xMidYMid meet"/>
  </g>""" if enable_shadow else ""

        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="64" height="64">
  <defs>
    <linearGradient id="squircle-grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="{top_color}"/>
      <stop offset="100%" stop-color="{bottom_color}"/>
    </linearGradient>
    {shadow_filter}
  </defs>
  <!-- Drop shadow WhiteSur -->
  <image xlink:href="{SHADOW_BASE64}" width="60.882" height="62.001" x="1.559" y="1.999" preserveAspectRatio="none"/>
  <!-- Squircle Base -->
  <rect width="56" height="56" x="4" y="4" fill="url(#squircle-grad)" rx="13" ry="13"/>
  <!-- Centered Logo -->
  {shadow_element}
  <g transform="translate({emblem_x}, {emblem_y})">
    <image xlink:href="{img_b64}" width="{emblem_size}" height="{emblem_size}" preserveAspectRatio="xMidYMid meet"/>
  </g>
</svg>"""

    return svg.strip()


def render_svg_to_pixbuf(svg_string: str, size: int = 64) -> Optional[GdkPixbuf.Pixbuf]:
    """Renders SVG string directly into a GdkPixbuf in memory."""
    try:
        loader = GdkPixbuf.PixbufLoader.new_with_type("svg")
        loader.set_size(size, size)
        loader.write(svg_string.encode("utf-8"))
        loader.close()
        return loader.get_pixbuf()
    except Exception as e:
        print(f"Error rendering SVG to Pixbuf: {e}")
        return None


def save_icon_bundle(svg_string: str, icon_slug: str) -> Tuple[bool, str]:
    """
    Saves the generated icon across WhiteSur, hicolor, and vitrum-kde directories,
    and exports high-resolution 512x512 and 256x256 PNGs.
    """
    try:
        # Ensure directories exist
        for d in [WHITESUR_SCALABLE_DIR, HICOLOR_SCALABLE_DIR, HICOLOR_512_DIR, HICOLOR_256_DIR, VITRUM_ICONOS_DIR]:
            d.mkdir(parents=True, exist_ok=True)

        svg_filename = f"{icon_slug}.svg"
        png_filename = f"{icon_slug}.png"

        # 1. Save SVG files
        for target_dir in [WHITESUR_SCALABLE_DIR, HICOLOR_SCALABLE_DIR, VITRUM_ICONOS_DIR]:
            svg_path = target_dir / svg_filename
            svg_path.write_text(svg_string, encoding="utf-8")

        # 2. Render and save PNG files
        pb_512 = render_svg_to_pixbuf(svg_string, 512)
        if pb_512:
            pb_512.savev(str(HICOLOR_512_DIR / png_filename), "png", [], [])

        pb_256 = render_svg_to_pixbuf(svg_string, 256)
        if pb_256:
            pb_256.savev(str(HICOLOR_256_DIR / png_filename), "png", [], [])

        return True, str(WHITESUR_SCALABLE_DIR / svg_filename)
    except Exception as e:
        return False, str(e)
