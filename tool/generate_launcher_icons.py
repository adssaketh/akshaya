#!/usr/bin/env python3
"""Generates the Akshaya Patra launcher icons and the SVG logo.

Draws the basket logo (the same geometry as lib/core/design/widgets/
akshaya_logo.dart) with Pillow and writes:

  android/app/src/main/res/mipmap-*/ic_launcher.png            legacy icon
  android/app/src/main/res/drawable-*/ic_launcher_foreground.png   adaptive
  android/app/src/main/res/drawable-*/ic_launcher_monochrome.png   themed
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  android/app/src/main/res/values/ic_launcher_background.xml
  assets/branding/akshaya_patra_logo.svg
  assets/branding/akshaya_patra_icon_512.png

Run from the repository root:  python3 tool/generate_launcher_icons.py
Needs Pillow (pip install pillow). Colours are the light-theme tokens from
lib/core/design/tokens/akshaya_colors.dart.
"""

from __future__ import annotations

import math
import os

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
        save(render(px, 0.82, tile=True), f"{RES}/mipmap-{name}/ic_launcher.png")

    # Adaptive icons: 108 dp canvas; the artwork is 60 dp tall (was 50) and
    # still inside the 66 dp safe circle: the farthest points (handle top,
    # basket bottom corners) sit about 0.7 x 60 / 0.92 dp = 32.6 dp from the
    # centre, under the 33 dp radius.
    density = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, factor in density.items():
        px = round(108 * factor)
        save(render(px, 60 / 108), f"{RES}/drawable-{name}/ic_launcher_foreground.png")
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

    save(render(512, 0.82, tile=True), "assets/branding/akshaya_patra_icon_512.png")
    write_svg("assets/branding/akshaya_patra_logo.svg")


def hexs(rgb):
    return "#%02X%02X%02X" % rgb


def write_svg(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="512" height="512" role="img">
  <title>Akshaya Patra</title>
  <rect x="2" y="2" width="116" height="116" rx="28" fill="{hexs(CREAM)}"/>
  <path d="M36 60 C36 12 84 12 84 60" fill="none" stroke="{hexs(BROWN)}" stroke-width="3.5" stroke-linecap="round"/>
  <rect x="39" y="34" width="14" height="28" rx="3" fill="{hexs(BOTTLE)}"/>
  <rect x="42" y="28" width="8" height="7" rx="2" fill="{hexs(TURMERIC)}"/>
  <path d="M58 62 L70 62 L64 34 Z" fill="{hexs(TURMERIC)}"/>
  <path d="M64 34 C58 24 60 20 64 18 C68 20 70 24 64 34 Z" fill="{hexs(LEAF)}"/>
  <ellipse cx="78" cy="48" rx="5" ry="13" transform="rotate(22 78 48)" fill="{hexs(LEAF)}"/>
  <ellipse cx="85" cy="52" rx="4" ry="11" transform="rotate(50 85 52)" fill="{hexs(LEAF_LIGHT)}"/>
  <path d="M30 63 L90 63 L84 99 Q83.5 103 79.5 103 L40.5 103 Q36.5 103 36 99 Z" fill="{hexs(TERRACOTTA)}"/>
  <rect x="27" y="58" width="66" height="9" rx="4.5" fill="{hexs(BROWN)}"/>
  <g stroke="{hexs(CREAM)}" stroke-width="2.2" stroke-linecap="round" fill="none">
    <line x1="34" y1="79" x2="86" y2="79"/>
    <line x1="36" y1="91" x2="84" y2="91"/>
    <line x1="48" y1="68" x2="46" y2="100"/>
    <line x1="60" y1="68" x2="60" y2="100"/>
    <line x1="72" y1="68" x2="74" y2="100"/>
  </g>
  <circle cx="60" cy="85" r="2.6" fill="{hexs(TURMERIC)}"/>
</svg>
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(svg)
    print("wrote", path)


if __name__ == "__main__":
    main()
