"""Split a generated portrait track sheet into two seamless runtime strips."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


def _seamless_strip(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    crop = source.crop(box).resize((256, 512), Image.Resampling.LANCZOS)
    seamless = Image.new("RGB", (256, 1024))
    seamless.paste(crop, (0, 0))
    seamless.paste(ImageOps.flip(crop), (0, 512))
    return seamless


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--track-id", required=True)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGB")
    width, height = source.size
    side_width = max(1, round(width * 0.30))
    sample_height = min(height, side_width * 2)
    top = (height - sample_height) // 2
    boxes = {
        "left": (0, top, side_width, top + sample_height),
        "right": (width - side_width, top, width, top + sample_height),
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for side, box in boxes.items():
        output = args.output_dir / f"{args.track_id}_{side}.png"
        strip = _seamless_strip(source, box)
        strip.save(output, optimize=True)
        print(f"Wrote {output} at {strip.size}")


if __name__ == "__main__":
    main()
