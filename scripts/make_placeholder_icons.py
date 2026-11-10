#!/usr/bin/env python3
"""Рисует иконки-заглушки (кольцо из бусин) для iOS и macOS по размерам из Contents.json.

Запуск: python3 scripts/make_placeholder_icons.py   (нужен Pillow). Настоящие иконки придут из Claude Design.
"""
import json
import math
import pathlib

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

ROOT = pathlib.Path(__file__).resolve().parent.parent
SETS = {
    "ios": ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset",
    "macos": ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset",
}
COLORS = [(233, 120, 150), (245, 190, 90), (120, 200, 170), (110, 150, 235), (190, 130, 230)]


def draw(px: int, alpha: bool) -> Image.Image:
    scale = 4  # сглаживание
    size = px * scale
    img = Image.new("RGB", (size, size), (34, 38, 56))
    d = ImageDraw.Draw(img)
    centre, ring, bead = size / 2, size * 0.32, size * 0.085
    count = 15
    for i in range(count):
        a = 2 * math.pi * i / count - math.pi / 2
        x, y = centre + ring * math.cos(a), centre + ring * math.sin(a)
        d.ellipse((x - bead, y - bead, x + bead, y + bead), fill=COLORS[i % len(COLORS)])
        h = bead * 0.35
        d.ellipse((x - bead * .5, y - bead * .6, x - bead * .5 + h, y - bead * .6 + h), fill=(255, 255, 255))
    out = img.resize((px, px), Image.LANCZOS)
    return out.convert("RGBA") if alpha else out


def main() -> None:
    meta = PngInfo()
    meta.add_text("Comment", "beading-placeholder")
    for platform, folder in SETS.items():
        contents = json.loads((folder / "Contents.json").read_text())
        for entry in contents["images"]:
            name = entry.get("filename")
            if not name:
                continue
            base = float(entry["size"].split("x")[0])
            px = round(base * float(entry["scale"].rstrip("x")))
            # iOS не принимает прозрачность в значке; macOS можно, но заглушке хватает сплошного фона.
            draw(px, alpha=False).save(folder / name, pnginfo=meta)
            print(f"{platform}: {name} {px}px")


if __name__ == "__main__":
    main()
