"""Create a centered gameplay sprite without changing the source aspect ratio."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def prepare(source: Path, output: Path, canvas: tuple[int, int], bounds: tuple[int, int]) -> dict[str, object]:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
    if bbox is None:
        raise ValueError(f"{source} has no visible pixels")

    subject = image.crop(bbox)
    scale = min(bounds[0] / subject.width, bounds[1] / subject.height)
    target = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(target, Image.Resampling.LANCZOS)

    result = Image.new("RGBA", canvas, (0, 0, 0, 0))
    anchor = ((canvas[0] - target[0]) // 2, (canvas[1] - target[1]) // 2)
    result.alpha_composite(subject, anchor)
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output, optimize=True)
    return {
        "source": source.as_posix(),
        "output": output.as_posix(),
        "source_bbox": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "runtime_bbox": list(target),
        "uniform_scale": scale,
        "canvas": list(canvas),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--canvas", nargs=2, type=int, required=True)
    parser.add_argument("--bounds", nargs=2, type=int, required=True)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    record = prepare(args.source, args.output, tuple(args.canvas), tuple(args.bounds))
    if args.manifest:
        records = json.loads(args.manifest.read_text("utf-8")) if args.manifest.exists() else {}
        records[args.output.stem] = record
        args.manifest.write_text(json.dumps(records, indent=2) + "\n", "utf-8")
    print(json.dumps(record))


if __name__ == "__main__":
    main()
