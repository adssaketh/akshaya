#!/usr/bin/env python3
"""Generates the Akshaya Patra launcher icons and the SVG logo.

Draws the basket logo (the same geometry as lib/core/design/widgets/
akshaya_logo.dart). The coloured icons are rendered from a shaded, 3D-style
SVG with rsvg-convert; the monochrome (themed) icon is a flat silhouette
drawn with Pillow. Writes:

  android/app/src/main/res/mipmap-*/ic_launcher.png            legacy icon
  android/app/src/main/res/drawable-*/ic_launcher_foreground.png   adaptive
  android/app/src/main/res/drawable-*/ic_launcher_monochrome.png   themed
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  android/app/src/main/res/values/ic_launcher_background.xml
  assets/branding/akshaya_patra_logo.svg
  assets/branding/akshaya_patra_icon_512.png

Run from the repository root:  python3 tool/generate_launcher_icons.py
Needs Pillow (pip install pillow) and rsvg-convert (librsvg). Colours are the light-theme tokens from
lib/core/design/tokens/akshaya_colors.dart.
"""

from __future__ import annotations

import math
import os
import subprocess

from PIL import Image, ImageDraw

CREAM = (0xFB, 0xF5, 0xEC)
BROWN = (0x2B, 0x1D, 0x14)
TERRACOTTA = (0xB5, 0x50, 0x2D)
TURMERIC = (0xE3, 0xA2, 0x1A)
LEAF = (0x3F, 0x6F, 0x2E)
LEAF_LIGHT = (0x77, 0x97, 0x67)  # LEAF at 70% over CREAM
BOTTLE = (0x24, 0x5F, 0x85)

RES = "android/app/src/main/res"
SUPERSAMPLE = 4

# Content bounds on the 120-unit grid (see the logo widget).
TOP, HEIGHT, CENTRE_X = 14.0, 92.0, 60.0


def bezier(p0, p1, p2, p3, steps=48):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        pts.append((
            u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
        ))
    return pts


def quad(p0, p1, p2, steps=16):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        pts.append((
            u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
        ))
    return pts


def ellipse_points(cx, cy, rx, ry, degrees, steps=48):
    a = math.radians(degrees)
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * math.cos(a) - y * math.sin(a),
                    cy + x * math.sin(a) + y * math.cos(a)))
    return pts


class Canvas:
    """Draws on the 120-unit grid, mapped into a pixel square."""

    def __init__(self, img, size, content_height_px, mono=False):
        self.d = ImageDraw.Draw(img)
        self.mono = mono
        self.s = content_height_px / HEIGHT
        self.ox = size / 2 - CENTRE_X * self.s
        self.oy = size / 2 - (TOP + HEIGHT / 2) * self.s

    def _p(self, pt):
        return (self.ox + pt[0] * self.s, self.oy + pt[1] * self.s)

    def _c(self, rgb, hole=False):
        if self.mono:
            return (0, 0, 0, 0) if hole else (0, 0, 0, 255)
        return rgb + (255,)

    def polygon(self, pts, rgb):
        self.d.polygon([self._p(p) for p in pts], fill=self._c(rgb))

    def rrect(self, x, y, w, h, r, rgb):
        a, b = self._p((x, y)), self._p((x + w, y + h))
        self.d.rounded_rectangle([a, b], radius=r * self.s, fill=self._c(rgb))

    def circle(self, cx, cy, r, rgb, hole=False):
        a, b = self._p((cx - r, cy - r)), self._p((cx + r, cy + r))
        self.d.ellipse([a, b], fill=self._c(rgb, hole))

    def line(self, pts, width, rgb, hole=False):
        pp = [self._p(p) for p in pts]
        w = width * self.s
        fill = self._c(rgb, hole)
        self.d.line(pp, fill=fill, width=max(1, round(w)), joint="curve")
        r = w / 2
        for x, y in (pp[0], pp[-1]):
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def draw_logo(img, size, content_height_px, mono=False):
    c = Canvas(img, size, content_height_px, mono)

    c.line(bezier((36, 60), (36, 12), (84, 12), (84, 60)), 3.5, BROWN)

    c.rrect(39, 34, 14, 28, 3, BOTTLE)
    c.rrect(42, 28, 8, 7, 2, TURMERIC)

    c.polygon([(58, 62), (70, 62), (64, 34)], TURMERIC)
    c.polygon(
        bezier((64, 34), (58, 24), (60, 20), (64, 18))
        + bezier((64, 18), (68, 20), (70, 24), (64, 34)),
        LEAF,
    )

    c.polygon(ellipse_points(78, 48, 5, 13, 22), LEAF)
    c.polygon(ellipse_points(85, 52, 4, 11, 50), LEAF_LIGHT)

    basket = [(30, 63), (90, 63), (84, 99)]
    basket += quad((84, 99), (83.5, 103), (79.5, 103))
    basket += [(40.5, 103)]
    basket += quad((40.5, 103), (36.5, 103), (36, 99))
    c.polygon(basket, TERRACOTTA)
    c.rrect(27, 58, 66, 9, 4.5, BROWN)

    for pts in (
        [(34, 79), (86, 79)],
        [(36, 91), (84, 91)],
        [(48, 68), (46, 100)],
        [(60, 68), (60, 100)],
        [(72, 68), (74, 100)],
    ):
        c.line(pts, 2.2, CREAM, hole=True)
    c.circle(60, 85, 2.6, TURMERIC, hole=True)


# The 3D-style artwork on the 120-unit grid (content spans x 27..93, y 14..108).
# Light comes from the top left: every body has a lit left edge, a shaded right
# edge and a soft highlight, and the basket casts a blurred shadow.
ART = """
  <defs>
    <linearGradient id="basket" x1="0" y1="0" x2="1" y2="0.35">
      <stop offset="0" stop-color="#E07A52"/>
      <stop offset="0.45" stop-color="#B5502D"/>
      <stop offset="1" stop-color="#7A2F14"/>
    </linearGradient>
    <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#6B4A35"/>
      <stop offset="0.5" stop-color="#2B1D14"/>
      <stop offset="1" stop-color="#150D08"/>
    </linearGradient>
    <linearGradient id="bottle" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#5BA4D1"/>
      <stop offset="0.5" stop-color="#245F85"/>
      <stop offset="1" stop-color="#143A55"/>
    </linearGradient>
    <linearGradient id="cap" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFD66B"/>
      <stop offset="1" stop-color="#C88A0C"/>
    </linearGradient>
    <linearGradient id="carrot" x1="0" y1="0" x2="1" y2="0.2">
      <stop offset="0" stop-color="#FFC24A"/>
      <stop offset="0.55" stop-color="#E3A21A"/>
      <stop offset="1" stop-color="#B07304"/>
    </linearGradient>
    <linearGradient id="leaf" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#7FB868"/>
      <stop offset="0.5" stop-color="#3F6F2E"/>
      <stop offset="1" stop-color="#27481B"/>
    </linearGradient>
    <linearGradient id="leaf2" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#A9CF96"/>
      <stop offset="1" stop-color="#5E8A4C"/>
    </linearGradient>
    <radialGradient id="shadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#2B1D14" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#2B1D14" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <ellipse cx="62" cy="106" rx="34" ry="5" fill="url(#shadow)"/>
  <path d="M36 60 C36 12 84 12 84 60" fill="none" stroke="#150D08" stroke-width="5" stroke-linecap="round" opacity="0.35" transform="translate(1.2 1.8)"/>
  <path d="M36 60 C36 12 84 12 84 60" fill="none" stroke="url(#rim)" stroke-width="4" stroke-linecap="round"/>
  <rect x="39" y="34" width="14" height="28" rx="3.5" fill="url(#bottle)"/>
  <rect x="41" y="36" width="3" height="22" rx="1.5" fill="#FFFFFF" fill-opacity="0.35"/>
  <rect x="42" y="28" width="8" height="7.5" rx="2.2" fill="url(#cap)"/>
  <rect x="43" y="29" width="6" height="2" rx="1" fill="#FFFFFF" fill-opacity="0.5"/>
  <path d="M58 62 L70 62 L64 34 Z" fill="url(#carrot)"/>
  <path d="M60.5 60 L64 40" stroke="#FFFFFF" stroke-opacity="0.4" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M63 50 L67.5 50 M62 56 L68.6 56" stroke="#B07304" stroke-opacity="0.55" stroke-width="1" stroke-linecap="round"/>
  <path d="M64 34 C58 24 60 20 64 18 C68 20 70 24 64 34 Z" fill="url(#leaf)"/>
  <path d="M63.2 31 C61.5 26 62 22 64 20.5" stroke="#FFFFFF" stroke-opacity="0.4" stroke-width="1" fill="none" stroke-linecap="round"/>
  <ellipse cx="78" cy="48" rx="5" ry="13" transform="rotate(22 78 48)" fill="url(#leaf)"/>
  <ellipse cx="76.4" cy="44" rx="1.3" ry="7" transform="rotate(22 76.4 44)" fill="#FFFFFF" fill-opacity="0.35"/>
  <ellipse cx="85" cy="52" rx="4" ry="11" transform="rotate(50 85 52)" fill="url(#leaf2)"/>
  <path d="M30 63 L90 63 L84 99 Q83.5 103 79.5 103 L40.5 103 Q36.5 103 36 99 Z" fill="url(#basket)"/>
  <path d="M33 66 L37.5 98" stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="2" stroke-linecap="round"/>
  <g fill="none" stroke-linecap="round">
    <g stroke="#4A1E0C" stroke-opacity="0.55" stroke-width="2.4">
      <line x1="34" y1="80.2" x2="86" y2="80.2"/>
      <line x1="36" y1="92.2" x2="84" y2="92.2"/>
      <line x1="48.8" y1="68" x2="46.8" y2="100"/>
      <line x1="60.8" y1="68" x2="60.8" y2="100"/>
      <line x1="72.8" y1="68" x2="74.8" y2="100"/>
    </g>
    <g stroke="#FFE2CF" stroke-opacity="0.85" stroke-width="1.7">
      <line x1="34" y1="79" x2="86" y2="79"/>
      <line x1="36" y1="91" x2="84" y2="91"/>
      <line x1="48" y1="68" x2="46" y2="100"/>
      <line x1="60" y1="68" x2="60" y2="100"/>
      <line x1="72" y1="68" x2="74" y2="100"/>
    </g>
  </g>
  <rect x="27" y="58" width="66" height="9" rx="4.5" fill="url(#rim)"/>
  <rect x="30" y="59.2" width="60" height="2.6" rx="1.3" fill="url(#gloss)"/>
  <circle cx="60" cy="85" r="3.2" fill="url(#cap)"/>
  <circle cx="59" cy="84" r="1" fill="#FFFFFF" fill-opacity="0.7"/>
"""

TILE_DEFS = """
  <defs>
    <radialGradient id="tile" cx="0.3" cy="0.2" r="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="0.55" stop-color="#FBF5EC"/>
      <stop offset="1" stop-color="#EBD9BF"/>
    </radialGradient>
  </defs>
"""


def svg_icon(size, content_fraction, tile=False):
    """The coloured artwork as an SVG sized [size] px, centred like render()."""
    scale = size * content_fraction / HEIGHT
    # The artwork's visual centre is (60, 60).
    transform = f"translate({size / 2} {size / 2}) scale({scale}) translate(-60 -60)"
    background = ""
    if tile:
        background = (
            TILE_DEFS
            + f'  <rect width="{size}" height="{size}" rx="{size * 0.22}" fill="url(#tile)"/>\n'
        )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}">\n{background}<g transform="{transform}">{ART}</g>\n</svg>\n'
    )


def render_svg(size, content_fraction, tile=False):
    svg = svg_icon(size, content_fraction, tile)
    png = subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size)],
        input=svg.encode("utf-8"),
        check=True,
        capture_output=True,
    ).stdout
    import io
    return Image.open(io.BytesIO(png)).convert("RGBA")


def render(size, content_fraction, background=None, mono=False, tile=False):
    big = size * SUPERSAMPLE
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    if tile:
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.22,
                            fill=CREAM + (255,))
    elif background is not None:
        img.paste(background + (255,), [0, 0, big, big])
    draw_logo(img, big, big * content_fraction, mono)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", path)


def main():
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, px in legacy.items():
        save(render_svg(px, 0.82, tile=True), f"{RES}/mipmap-{name}/ic_launcher.png")

    # Adaptive icons: 108 dp canvas; the artwork is 60 dp tall (was 50) and
    # still inside the 66 dp safe circle: the farthest points (handle top,
    # basket bottom corners) sit about 0.7 x 60 / 0.92 dp = 32.6 dp from the
    # centre, under the 33 dp radius.
    density = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, factor in density.items():
        px = round(108 * factor)
        save(render_svg(px, 60 / 108), f"{RES}/drawable-{name}/ic_launcher_foreground.png")
        save(render(px, 60 / 108, mono=True),
             f"{RES}/drawable-{name}/ic_launcher_monochrome.png")

    os.makedirs(f"{RES}/mipmap-anydpi-v26", exist_ok=True)
    with open(f"{RES}/mipmap-anydpi-v26/ic_launcher.xml", "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
            "</adaptive-icon>\n"
        )
    with open(f"{RES}/values/ic_launcher_background.xml", "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#FBF5EC</color>\n'
            "</resources>\n"
        )

    save(render_svg(512, 0.82, tile=True), "assets/branding/akshaya_patra_icon_512.png")
    write_svg("assets/branding/akshaya_patra_logo.svg")


def hexs(rgb):
    return "#%02X%02X%02X" % rgb


def write_svg(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(svg_icon(512, 0.82, tile=True).replace(
            "<svg ", '<svg role="img" ', 1).replace(
            "\n<g ", "\n<title>Akshaya Patra</title>\n<g ", 1))
    print("wrote", path)


if __name__ == "__main__":
    main()
