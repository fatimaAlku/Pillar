#!/usr/bin/env python3
"""Build iOS AppIcon.appiconset PNGs from branding/pillar_logo.png (pillar mark only)."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image  # pyright: ignore[reportMissingImports]
except ImportError:
    print(
        "Install Pillow: python3 -m venv .venv && .venv/bin/pip install -r scripts/requirements.txt",
        file=sys.stderr,
    )
    raise

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "branding" / "pillar_logo.png"
OUT_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

# (filename, pixel_size)
ICON_SIZES: list[tuple[str, int]] = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

# Fraction of source width: only the pillar graphic + gold accent (no “PILLAR” text).
# Full wordmark starts further right on branding/pillar_logo.png (690px wide).
_MARK_WIDTH_RATIO = 0.29


def make_master_1024(src: Path) -> Image.Image:
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    crop_w = max(1, int(w * _MARK_WIDTH_RATIO))
    cropped = img.crop((0, 0, crop_w, h))
    side = max(cropped.width, cropped.height)
    bg = (248, 250, 252, 255)
    sq = Image.new("RGBA", (side, side), bg)
    ox = (side - cropped.width) // 2
    oy = (side - cropped.height) // 2
    sq.paste(cropped, (ox, oy), cropped)
    return sq.resize((1024, 1024), Image.Resampling.LANCZOS)


def main() -> None:
    if not SRC.is_file():
        raise SystemExit(f"Missing source: {SRC}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    master = make_master_1024(SRC)
    for name, size in ICON_SIZES:
        out = master.resize((size, size), Image.Resampling.LANCZOS)
        # App Store marketing icon must be RGB, no alpha.
        if size == 1024:
            out = out.convert("RGB")
        out.save(OUT_DIR / name, format="PNG")
    print(f"Wrote {len(ICON_SIZES)} icons to {OUT_DIR}")


if __name__ == "__main__":
    main()
