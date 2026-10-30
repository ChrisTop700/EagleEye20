"""Render the Eagle Eye 20 SVG artwork into WoW-ready TGA textures.

Run from the repository root:
    python tools/build_textures.py

Requires: pip install resvg-py pillow

The SVG sources live at the repository root. This script writes the
Interface\\AddOns\\EagleEye20\\Textures textures listed in the .toc:
    Icon.tga       square app/addon icon (256x256), used as-is from the SVG
    IconRound.tga  circular minimap button icon (128x128), same eye artwork
                   with the square button frame removed and fitted to a disc
    Logo.tga       full logo used by the options panel and blackout

Both icon textures are derived from `Eagle Eye 20 Icon.svg`, so editing that
one file updates the addon icon and the minimap button together.
"""

import io
import os
import re

import resvg_py
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXTURES = os.path.join(ROOT, "Textures")

ICON_SVG = os.path.join(ROOT, "assets", "Eagle Eye 20 Icon.svg")
LOGO_SVG = os.path.join(ROOT, "assets", "Eagle Eye 20 Logo.svg")

# Share of the texture width the eye artwork fills inside the round button.
ROUND_FIT = 0.90
ROUND_BG = (10, 14, 18, 255)
ROUND_RING = (40, 40, 52, 255)


def render(svg_path=None, svg_string=None, size=256):
    png = resvg_py.svg_to_bytes(svg_path=svg_path, svg_string=svg_string, width=size, height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def save(img, name):
    path = os.path.join(TEXTURES, name)
    img.save(path, format="TGA", compression="tga_rle")
    print("%-14s %dx%d  %d bytes" % (name, img.width, img.height, os.path.getsize(path)))


def circle_mask(size):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return mask


def build_round_icon(icon_svg_path, size=128, supersample=4):
    """Disc-shaped minimap button carrying the same eye as the square icon.

    The square icon's button frame is stripped so the round variant is only the
    eye, mountains and reticle, then centred inside a circular badge. Deriving
    it from the SVG keeps both textures in sync.
    """
    svg = open(icon_svg_path, encoding="utf-8").read()
    frameless = re.sub(r'<rect x="6" y="6"[^/]*/>', "", svg)

    big = size * supersample
    art = render(svg_string=frameless, size=big)
    art = art.crop(art.getbbox())

    badge = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(badge)
    draw.ellipse((0, 0, big - 1, big - 1), fill=ROUND_BG)
    draw.ellipse((3, 3, big - 4, big - 4), outline=ROUND_RING, width=3)

    width = int(big * ROUND_FIT)
    height = max(1, int(width * art.height / art.width))
    badge.alpha_composite(art.resize((width, height), Image.LANCZOS),
                          ((big - width) // 2, (big - height) // 2))
    badge.putalpha(Image.composite(badge.getchannel("A"),
                                   Image.new("L", (big, big), 0),
                                   circle_mask(big)))
    return badge.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(TEXTURES, exist_ok=True)

    icon = render(svg_path=ICON_SVG, size=256)
    save(icon, "Icon.tga")

    logo = render(svg_path=LOGO_SVG, size=256)
    save(logo, "Logo.tga")

    save(build_round_icon(ICON_SVG), "IconRound.tga")


if __name__ == "__main__":
    main()
