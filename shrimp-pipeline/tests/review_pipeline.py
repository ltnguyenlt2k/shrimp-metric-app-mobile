"""Render a review video of the pipeline on held-out and unlabelled tray images.

    python tests/review_pipeline.py [--models artifacts/detect-v3 artifacts/lite-v1]

Each slide: input image, one overlay per model, labelled count, predicted count and error,
plus the running error so far. The last slide is the per-source summary. Needs ffmpeg.
"""
import argparse
import io
import json
import random
import subprocess
import sys
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "pipeline"))
import run  # noqa: E402
from data import load_rows  # noqa: E402
from evaluate_detect import mosaics, truth_boxes  # noqa: E402

WIDTH, HEIGHT, PANEL = 1920, 1080, 190
PER_SOURCE = {"jala": 14, "thenho": 7, "csiro": 8, "vannamei": 3}
NAMES = {"jala": "JALA - tom the song trong khay", "thenho": "TheNho - tom lon trong khay",
         "csiro": "CSIRO - tom su tren sang luoi o ao", "vannamei": "Vannamei - anh tung con",
         "mosaic-2x2": "Thu tom nho: ghep 4 anh khay test vao 1 khung 2048x1536",
         "mosaic-3x3": "Thu tom rat nho: ghep 9 anh khay test vao 1 khung 2048x1536",
         "unlabeled": "Khay ngoai tap train, KHONG co nhan (chi xem bang mat)"}


def font(size):
    return ImageFont.load_default(size=size)


def fit(image, width, height):
    image = image.copy()
    image.thumbnail((width, height))
    return image


def slide(original, overlays, lines):
    canvas = Image.new("RGB", (WIDTH, HEIGHT), (18, 20, 24))
    columns = 1 + len(overlays)
    cell = WIDTH // columns
    for k, (title, picture) in enumerate([("Anh dau vao", original)] + overlays):
        view = fit(picture, cell - 16, HEIGHT - PANEL - 50)
        canvas.paste(view, (k * cell + (cell - view.width) // 2, 44))
        ImageDraw.Draw(canvas).text((k * cell + 12, 8), title, fill=(255, 255, 255), font=font(26))
    pen = ImageDraw.Draw(canvas)
    for k, (text, color) in enumerate(lines):
        pen.text((24, HEIGHT - PANEL + 8 + k * 42), text, fill=color, font=font(32))
    return canvas


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", type=Path, nargs="+", default=[ROOT / "artifacts/detect-v3", ROOT / "artifacts/phone-v1"])
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/review")
    parser.add_argument("--seconds", type=float, default=3.0)
    args = parser.parse_args()
    detectors = [run.load_detector(path) for path in args.models]
    frames = args.output / "frames"
    frames.mkdir(parents=True, exist_ok=True)
    for old in frames.glob("*.jpg"):
        old.unlink()
    rows = [row for row in load_rows() if row["split"] == "test"]
    random.seed(11)
    picked = []
    for source, count in PER_SOURCE.items():
        pool = [row for row in rows if row["source"] == source]
        picked += random.sample(pool, min(count, len(pool)))
    items = [(row["source"], row["name"].split("/")[-1][:40], Image.open(io.BytesIO(row["image"])).convert("RGB"),
              len(truth_boxes(row))) for row in picked]
    trays = [row for row in rows if row["source"] in ("jala", "thenho")]
    for n, count in ((2, 4), (3, 2)):
        for item in list(mosaics(trays, n))[:count]:
            items.append((item["source"], item["name"], item["picture"], len(item["truth"])))
    for path in sorted((ROOT / "artifacts/external/tray-unlabeled").glob("*.jpg")):
        items.append(("unlabeled", path.name, ImageOps.exif_transpose(Image.open(path)).convert("RGB"), None))
    errors = [defaultdict(list) for _ in detectors]
    index = 0
    for source, name, original, truth in items:
        overlays, lines = [], [(f"{NAMES[source]}   |   {name}", (200, 200, 200))]
        for d, detector in enumerate(detectors):
            started = time.perf_counter()
            image, _, mode, boxes, _, crops = detector(original)
            seconds = time.perf_counter() - started
            overlays.append((f"{detector.version}: {len(boxes)} con ({mode}, {seconds:.2f} s tren {detector.device} PC)",
                             run.draw(image, boxes, crops, "")))
            if truth is None:
                lines.append((f"{detector.version}: du doan {len(boxes)} con   |   khong co nhan de tinh sai so",
                              (255, 220, 120)))
                continue
            error = len(boxes) - truth
            errors[d][source].append((error, truth))
            every = [e for values in errors[d].values() for e in values]
            mae = np.mean([abs(e) for e, _ in every])
            share = np.mean([abs(e) / max(t, 1) for e, t in every]) * 100
            color = (120, 230, 140) if error == 0 else (255, 200, 90) if abs(error) <= max(1, .05 * truth) else (255, 110, 110)
            lines.append((f"{detector.version}: that {truth} | du doan {len(boxes)} | lech {error:+d} "
                          f"({abs(error) / max(truth, 1) * 100:.1f}%)   ||   luy ke {len(every)} anh: "
                          f"sai so TB {mae:.2f} con ({share:.1f}%)", color))
        slide(original, overlays, lines).save(frames / f"{index:03d}.jpg", quality=90)
        index += 1
    summary = Image.new("RGB", (WIDTH, HEIGHT), (18, 20, 24))
    pen = ImageDraw.Draw(summary)
    pen.text((40, 30), "Tong ket tren cac anh co nhan trong video (tap test giu rieng)", fill=(255, 255, 255), font=font(44))
    y, report = 120, {}
    for d, detector in enumerate(detectors):
        pen.text((40, y), detector.version, fill=(120, 200, 255), font=font(38))
        y += 54
        report[detector.version] = {}
        for source, values in errors[d].items():
            mae = float(np.mean([abs(e) for e, _ in values]))
            share = float(np.mean([abs(e) / max(t, 1) for e, t in values]) * 100)
            exact = float(np.mean([e == 0 for e, _ in values]) * 100)
            report[detector.version][source] = {"images": len(values), "count_mae": round(mae, 2),
                                                "count_mape_percent": round(share, 1), "exact_percent": round(exact)}
            pen.text((70, y), f"{NAMES[source]}: {len(values)} anh | sai so TB {mae:.2f} con ({share:.1f}%) | "
                              f"dung tuyet doi {exact:.0f}%", fill=(230, 230, 230), font=font(30))
            y += 42
        y += 22
    pen.text((40, HEIGHT - 110), "Day la so tren dataset cong khai, chua phai do tren khay thuc te cua du an.",
             fill=(255, 200, 90), font=font(30))
    pen.text((40, HEIGHT - 66), "Video chi gom mot phan tap test; so day du nam trong tests/reports/.",
             fill=(200, 200, 200), font=font(28))
    for extra in range(2):
        summary.save(frames / f"{index + extra:03d}.jpg", quality=90)
    target = args.output / "pipeline-review.mp4"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(1 / args.seconds), "-i",
                    str(frames / "%03d.jpg"), "-c:v", "libx264", "-r", "30", "-pix_fmt", "yuv420p", str(target)],
                   check=True)
    (args.output / "pipeline-review.json").write_text(json.dumps(report, indent=1))
    print(json.dumps(report))
    print("Saved:", target)


if __name__ == "__main__":
    main()
