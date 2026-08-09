"""Crop a generated square scene into a seamless vertical scrolling strip."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--crop-x", type=int, required=True)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGB")
    crop_width = source.height // 2
    if args.crop_x < 0 or args.crop_x + crop_width > source.width:
        raise ValueError("Requested vertical crop is outside the source image")
    strip = source.crop((args.crop_x, 0, args.crop_x + crop_width, source.height))
    strip = strip.resize((256, 512), Image.Resampling.LANCZOS)

    seamless = Image.new("RGB", (256, 1024))
    seamless.paste(strip, (0, 0))
    seamless.paste(ImageOps.flip(strip), (0, 512))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    seamless.save(args.output, optimize=True)
    print(f"Wrote {args.output} at {seamless.size}")


if __name__ == "__main__":
    main()
