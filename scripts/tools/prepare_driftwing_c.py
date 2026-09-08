"""Extract the approved navy-background C artwork; never alter the source."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
rgb = np.array(Image.open(args.source).convert("RGB"))
r, g, b = [rgb[:, :, index].astype(float) for index in range(3)]
# Remove only navy pixels connected to the image exterior, preserving dark glass.
candidate = (r < 25) & (g < 40) & (b < 80) & (b > r * 1.5)
seed = np.zeros(candidate.shape, dtype=bool)
seed[0, :] = candidate[0, :]
seed[-1, :] = candidate[-1, :]
seed[:, 0] = candidate[:, 0]
seed[:, -1] = candidate[:, -1]
background = ndimage.binary_propagation(seed, mask=candidate)
mask = ndimage.binary_fill_holes(~background)
labels, count = ndimage.label(mask)
areas = np.bincount(labels.ravel())
areas[0] = 0
mask = areas[labels] > 100
alpha = np.clip(ndimage.distance_transform_edt(mask) / 1.5, 0, 1)
rgba = Image.fromarray(np.dstack([rgb, (alpha * 255).astype(np.uint8)]), "RGBA")
subject = rgba.crop(rgba.getchannel("A").getbbox())
# Uniform scaling only: the new plan-view art must not receive the legacy 1.22 stretch.
subject.thumbnail((640, 1280), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (800, 1360))
canvas.alpha_composite(subject, ((800-subject.width)//2, (1360-subject.height)//2))
args.output.parent.mkdir(parents=True, exist_ok=True)
canvas.save(args.output)
assert canvas.getpixel((0, 0))[3] == 0
assert canvas.getpixel((400, 680))[3] == 255
print({"size": canvas.size, "body": subject.size, "alpha_bbox": canvas.getchannel("A").getbbox()})
