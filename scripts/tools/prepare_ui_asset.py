"""Crop an alpha UI source and place it into a fixed runtime canvas.

UI frames are allowed to stretch to their target bounds: unlike vehicles, their
corners are decorative and their center is intentionally elastic.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--source", required=True, type=Path)
	parser.add_argument("--output", required=True, type=Path)
	parser.add_argument("--canvas", nargs=2, required=True, type=int)
	parser.add_argument("--bounds", nargs=2, required=True, type=int)
	args = parser.parse_args()

	image = Image.open(args.source).convert("RGBA")
	bbox = image.getchannel("A").getbbox()
	if bbox is None:
		raise ValueError(f"{args.source} contains no visible pixels")

	resampling = getattr(Image, "Resampling", Image).NEAREST
	subject = image.crop(bbox).resize(tuple(args.bounds), resampling)
	canvas = Image.new("RGBA", tuple(args.canvas), (0, 0, 0, 0))
	position = ((args.canvas[0] - args.bounds[0]) // 2, (args.canvas[1] - args.bounds[1]) // 2)
	canvas.alpha_composite(subject, position)
	args.output.parent.mkdir(parents=True, exist_ok=True)
	canvas.save(args.output)
	print({"source": str(args.source), "output": str(args.output), "source_bbox": bbox, "runtime_bbox": args.bounds})


if __name__ == "__main__":
	main()
