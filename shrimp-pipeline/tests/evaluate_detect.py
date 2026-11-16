"""Evaluate a detector through the real pipeline path on held-out images, per source.

    python tests/evaluate_detect.py [--model artifacts/detect-v3] [--split test]
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
from data import MAX_SIDE, decode, load_rows  # noqa: E402


def truth_boxes(row):
    image, masks = decode(row)
    with Image.open(io.BytesIO(row["image"])) as original:
        scale = min(1, MAX_SIDE / max(original.size))
    boxes = []
    for mask in masks:
        ys, xs = np.nonzero(mask)
        if len(xs):
            boxes.append([xs.min() / scale, ys.min() / scale, (xs.max() + 1) / scale, (ys.max() + 1) / scale])
    return torch.tensor(boxes, dtype=torch.float32).reshape(-1, 4)


def matches(predicted, truth):
    if not len(predicted) or not len(truth):
        return 0
    iou, used, hits = box_iou(predicted, truth), set(), 0
    for row in iou:  # predictions arrive sorted by score within a pass
        best = max((j for j in range(len(truth)) if j not in used), key=lambda j: row[j], default=None)
        if best is not None and row[best] >= .5:
            used.add(best)
            hits += 1
    return hits


def mosaics(rows, n, width=2048, height=1536):
    """Small-animal stress test: n x n held-out tray images tiled into one canonical frame, so
    every animal is n times smaller than in its own image. Yields rows with image and truth."""
    cell_w, cell_h = width // n, height // n
    for start in range(0, len(rows) - n * n + 1, n * n):
        canvas, boxes = Image.new("RGB", (width, height), (115, 115, 115)), []
        for k, row in enumerate(rows[start:start + n * n]):
            image = Image.open(io.BytesIO(row["image"])).convert("RGB")
            scale = min(cell_w / image.width, cell_h / image.height)
            x, y = k % n * cell_w, k // n * cell_h
            canvas.paste(image.resize((round(image.width * scale), round(image.height * scale))), (x, y))
            boxes.append(truth_boxes(row) * scale + torch.tensor([x, y, x, y], dtype=torch.float32))
        yield {"source": f"mosaic-{n}x{n}", "name": f"mosaic-{start // (n * n)}", "picture": canvas,
               "truth": torch.cat(boxes)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=ROOT / "artifacts/detect-v3")
    parser.add_argument("--split", default="test")
    parser.add_argument("--mode", default="auto", help="auto, whole (first pass only) or full (phone model: untiled second pass)")
    parser.add_argument("--mosaic", type=int, default=0, help="tile N x N tray test images into one frame")
    args = parser.parse_args()
    detector = run.load_detector(args.model)
    rows = [row for row in load_rows() if row["split"] == args.split]
    if args.mosaic:
        rows = list(mosaics([row for row in rows if row["source"] in ("jala", "thenho")], args.mosaic))
    stats = defaultdict(lambda: defaultdict(list))
    records = []
    for row in rows:
        original = row.get("picture") or Image.open(io.BytesIO(row["image"])).convert("RGB")
        truth = row["truth"] if "truth" in row else truth_boxes(row)
        _, scale, mode, boxes, scores, _ = detector(original, mode=args.mode)
        order = scores.argsort(descending=True)
        hits = matches(boxes[order] / scale, truth)
        error = len(boxes) - len(truth)
        for key in (row["source"], "all"):
            s = stats[key]
            s["error"].append(error)
            s["truth"].append(len(truth))
            s["tp"].append(hits)
            s["predicted"].append(len(boxes))
        records.append({"source": row["source"], "image": row["name"], "truth": len(truth),
                        "predicted": len(boxes), "matched": hits, "mode": mode})
    report = {"model": args.model.name, "split": args.split, "mode": args.mode,
              "threshold": detector.config["threshold"], "match": "box IoU >= 0.5", "sources": {}}
    for key, s in sorted(stats.items()):
        error, truth = np.array(s["error"]), np.array(s["truth"])
        tp, predicted = sum(s["tp"]), sum(s["predicted"])
        precision, recall = tp / max(1, predicted), tp / max(1, truth.sum())
        report["sources"][key] = {
            "images": len(error), "animals": int(truth.sum()),
            "animals_per_image_median": float(np.median(truth)),
            "count_mae": round(float(np.abs(error).mean()), 3),
            "count_bias": round(float(error.mean()), 3),
            "count_mape_percent": round(float((np.abs(error) / np.maximum(truth, 1)).mean() * 100), 2),
            "count_total_error_percent": round(float(error.sum() / max(1, truth.sum()) * 100), 2),
            "exact_share": round(float((error == 0).mean()), 3),
            "precision": round(precision, 4), "recall": round(recall, 4),
            "f1": round(2 * precision * recall / max(1e-9, precision + recall), 4)}
    suffix = (f"-mosaic{args.mosaic}" if args.mosaic else "") + ("" if args.mode == "auto" else f"-{args.mode}")
    target = ROOT / "tests/reports" / f"{args.model.name}-{args.split}{suffix}.json"
    target.write_text(json.dumps({**report, "images": records}, indent=1))
    for key, value in report["sources"].items():
        print(key, json.dumps(value))
    print("Saved:", target)


if __name__ == "__main__":
    main()
