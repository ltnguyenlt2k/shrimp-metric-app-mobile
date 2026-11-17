"""Reference data for the app: simulated-camera scenes and a parity fixture for the Dart port.

    python tests/app_fixtures.py

Writes
- `artifacts/app-sim/scenes/NN-<source>-<truth>.jpg`: held-out tray images as landscape 4:3
  canonical images (letterboxed, never enlarged past their own pixels), to push to the phone;
- `artifacts/app-sim/expected.json`: what `PhoneDetector` returns for those exact files on the PC,
  so the app's numbers on the same files can be compared;
- `../test/fixtures/lite/*`: one small image, its model output and the Python results for it,
  which `test/shrimp_lite_test.dart` checks the Dart code against.
"""
import io
import json
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image
import torch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "pipeline"))
import run  # noqa: E402
import gut  # noqa: E402
import size  # noqa: E402
from run import lite  # noqa: E402
from data import load_rows  # noqa: E402
from evaluate_detect import mosaics, truth_boxes  # noqa: E402

PX_PER_CM = 2048 / 38.6  # nominal scale of the app's placeholder calibration at 2048 px
PICK = {"jala": 8, "thenho": 3}


def canonical(image):
    """Landscape 4:3 on a grey canvas: 2048 x 1536 when the photo has the pixels, else 1024 x 768."""
    if image.height > image.width:
        image = image.transpose(Image.Transpose.ROTATE_90)
    width = 2048 if max(image.width, image.height * 4 / 3) >= 2048 else 1024
    height = width * 3 // 4
    scale = min(width / image.width, height / image.height)
    part = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (width, height), (115, 115, 115))
    canvas.paste(part, ((width - part.width) // 2, (height - part.height) // 2))
    return canvas


def analyse(detector, image):
    """The app's per-frame result for one canonical image, computed by the PC pipeline."""
    picture, _, mode, boxes, _, crops = detector(image)
    pixels = np.asarray(picture)
    scale = PX_PER_CM * picture.width / 2048
    lengths, guts, levels = [], [], {"empty": 0, "partial": 0, "full": 0, "not_observable": 0}
    for box, (x, y, mask) in zip(boxes, crops):
        edge = box[0] <= 2 or box[1] <= 2 or box[2] >= picture.width - 2 or box[3] >= picture.height - 2
        length = size.measure(mask)[0]
        if not edge and length > 0:
            lengths.append(length / scale)
        view = pixels[y:y + mask.shape[0], x:x + mask.shape[1]]
        result = {"index": None, "level": "not_observable"} if edge \
            else gut.gut_fullness(view, mask[:view.shape[0], :view.shape[1]])
        levels[result["level"]] += 1
        if result["index"] is not None:
            guts.append(result["index"])
    weights = [size.weight_from_length(cm)[0] for cm in lengths]
    return {"mode": mode, "count": len(boxes),
            "length_mm": round(float(np.mean(lengths)) * 10, 2) if lengths else None,
            "weight_g": round(float(np.mean(weights)), 4) if weights else None,
            "gut_index": round(float(np.mean(guts)), 3) if guts else None, "gut_levels": levels}


def main():
    detector = run.load_detector(ROOT / "artifacts/phone-v1")
    rows = [row for row in load_rows() if row["split"] == "test"]
    random.seed(23)
    scenes = []
    for source, count in PICK.items():
        for row in random.sample([r for r in rows if r["source"] == source], count):
            scenes.append((source, len(truth_boxes(row)), Image.open(io.BytesIO(row["image"])).convert("RGB")))
    trays = [row for row in rows if row["source"] in ("jala", "thenho")]
    for n, count in ((2, 2), (3, 1)):
        for item in list(mosaics(trays, n))[:count]:
            scenes.append((item["source"], len(item["truth"]), item["picture"]))
    for path in sorted((ROOT / "artifacts/external/tray-unlabeled").glob("*.jpg"))[:2]:
        scenes.append(("unlabeled", None, Image.open(path).convert("RGB")))
    folder = ROOT / "artifacts/app-sim/scenes"
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.jpg"):
        old.unlink()
    expected = {}
    for k, (source, truth, image) in enumerate(scenes):
        name = f"{k:02d}-{source}-{'x' if truth is None else truth}.jpg"
        canonical(image).save(folder / name, quality=93, subsampling=0)
        # Read the saved file back: the phone analyses the JPEG, not the original pixels.
        expected[name] = {"source": source, "truth": truth, **analyse(detector, Image.open(folder / name).convert("RGB"))}
        print(name, json.dumps(expected[name]), flush=True)
    (ROOT / "artifacts/app-sim/expected.json").write_text(json.dumps(expected, indent=1))

    # Parity fixture: a 512 x 384 crop of one tray image, run once at full size.
    fixture = ROOT.parent / "test/fixtures/lite"
    fixture.mkdir(parents=True, exist_ok=True)
    source = Image.open(folder / sorted(expected)[0]).convert("RGB")
    left, top = (source.width - 512) // 2, (source.height - 384) // 2
    crop = source.crop((left, top, left + 512, top + 384))
    tensor = (np.asarray(crop, np.float32) / 255).transpose(2, 0, 1)[None]
    maps = detector.session.run(None, {"rgb": tensor})[0][0]
    config = detector.config
    scores, items = lite.decode(torch.from_numpy(maps), config["threshold"], kernel=config["kernel"])
    order = scores.argsort(descending=True).tolist()
    pixels, animals = np.asarray(crop), []
    for i in order:
        x, y, cells = items[i]
        mask = np.kron(cells, np.ones((4, 4), bool))[:384 - y * 4, :512 - x * 4]
        x0, y0 = x * 4, y * 4
        edge = x0 <= 2 or y0 <= 2 or x0 + mask.shape[1] >= 510 or y0 + mask.shape[0] >= 382
        length, width = size.measure(mask)
        view = pixels[y0:y0 + mask.shape[0], x0:x0 + mask.shape[1]]
        fullness = {"index": None, "level": "not_observable"} if edge else gut.gut_fullness(view, mask)
        animals.append({"box": [x0, y0, x0 + mask.shape[1], y0 + mask.shape[0]], "score": round(float(scores[i]), 5),
                        "length_px": round(length, 3), "width_px": round(width, 3), "edge": bool(edge),
                        "gut_index": fullness["index"], "gut_level": fullness["level"]})
    (fixture / "image-512x384.rgb").write_bytes(pixels.tobytes())
    (fixture / "maps-4x96x128.f32").write_bytes(maps.astype("<f4").tobytes())
    small = source.crop((left, top, left + 64, top + 48))  # for the 2x reduction check
    (fixture / "half-in-64x48.rgb").write_bytes(np.asarray(small).tobytes())
    (fixture / "expected.json").write_text(json.dumps({
        "config": {k: config[k] for k in ("threshold", "kernel", "stride", "offset_scale", "min_cells")},
        "animals": animals,
        "weights_g": {str(cm): round(size.weight_from_length(cm)[0], 5) for cm in (1.25, 3.57, 5.0, 9.3, 14.0, 21.0)},
        "half_out_32x24": np.asarray(small.resize((32, 24), Image.Resampling.BILINEAR)).flatten().tolist(),
    }, indent=1))
    print("animals in fixture:", len(animals))


if __name__ == "__main__":
    main()
