"""How many pixels per animal are needed? Shrink held-out tray images and measure, per body
length in pixels, how often an animal is still found and how far its measured length drifts.

    python tests/scale_sweep.py [--model artifacts/detect-v3]
"""
import argparse
import io
import json
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image
import torch
from torchvision.ops import box_iou

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "pipeline"))
sys.path.insert(0, str(ROOT / "models/detect"))
import run  # noqa: E402
import size  # noqa: E402
from data import decode, load_rows  # noqa: E402

SCALES = [1.0, .75, .5, .35, .25, .18, .12, .08]
BINS = [0, 12, 16, 24, 32, 48, 64, 96, 160, 10000]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=ROOT / "artifacts/detect-v3")
    parser.add_argument("--sources", default="jala,thenho")
    args = parser.parse_args()
    detector = run.load_detector(args.model)
    threshold = detector.config["threshold"]
    rows = [row for row in load_rows() if row["split"] == "test" and row["source"] in args.sources.split(",")]
    found, errors, widths = defaultdict(list), defaultdict(list), defaultdict(list)
    for row in rows:
        image, masks = decode(row)
        truth = []
        for mask in masks:
            ys, xs = np.nonzero(mask)
            length, width = size.measure(mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
            truth.append(([xs.min(), ys.min(), xs.max() + 1, ys.max() + 1], length, width))
        truth_boxes = torch.tensor([t[0] for t in truth], dtype=torch.float32)
        for scale in SCALES:
            small = Image.fromarray(image).resize((max(32, round(image.shape[1] * scale)),
                                                   max(32, round(image.shape[0] * scale))), Image.Resampling.BILINEAR)
            boxes, scores, crops = detector.whole(small, threshold)
            iou = box_iou(boxes / scale, truth_boxes) if len(boxes) else torch.zeros((0, len(truth)))
            for j, (_, length, width) in enumerate(truth):
                pixels = length * scale
                k = int(np.digitize(pixels, BINS)) - 1
                best = int(iou[:, j].argmax()) if len(boxes) else -1
                hit = best >= 0 and float(iou[best, j]) >= .5
                found[k].append(hit)
                if hit:
                    measured = size.measure(crops[best][2])[0] / scale
                    errors[k].append(abs(measured - length) / length * 100)
                    widths[k].append(width * scale)
    table = []
    for k in range(len(BINS) - 1):
        if not found[k]:
            continue
        table.append({"length_px": f"{BINS[k]}-{BINS[k + 1]}" if BINS[k + 1] < 10000 else f">={BINS[k]}",
                      "animals": len(found[k]), "found_share": round(float(np.mean(found[k])), 3),
                      "length_error_median_percent": round(float(np.median(errors[k])), 1) if errors[k] else None,
                      "length_error_p90_percent": round(float(np.percentile(errors[k], 90)), 1) if errors[k] else None,
                      "body_width_px_median": round(float(np.median(widths[k])), 1) if widths[k] else None})
        print(json.dumps(table[-1]))
    target = ROOT / "tests/reports" / f"{args.model.name}-scale-sweep.json"
    target.write_text(json.dumps({"model": args.model.name, "sources": args.sources, "images": len(rows),
                                  "scales": SCALES, "note": "length_px is the labelled body length after shrinking; "
                                  "length error compares the predicted mask with the label mask of the same animal",
                                  "bins": table}, indent=1))
    print("Saved:", target)


if __name__ == "__main__":
    main()
