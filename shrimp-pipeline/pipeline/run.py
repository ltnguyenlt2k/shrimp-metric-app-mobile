"""Standalone tray pipeline: quality check -> localise -> count -> aggregate frames.

    python pipeline/run.py <image or folder of frames from one capture> [--output DIR]

A folder is treated as the 5-6 frames of one tray capture. The count is the mean over
valid frames and the overlay is drawn on one representative frame. Trays with many small
animals (PL) are re-run in overlapping tiles on the original resolution.
"""
import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps
import torch
from torch.nn import functional as F
from torchvision.ops import nms

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "models/detect"))
from train import build  # noqa: E402
sys.path.insert(0, str(ROOT / "pipeline"))
sys.path.insert(0, str(ROOT / "models/lite"))
import model as lite  # noqa: E402
import gut  # noqa: E402
import size  # noqa: E402

MAX_SIDE = 1280       # whole-frame pass, same limit as training
TILE_MAX_SIDE = 4160  # tiled pass works on the original resolution up to this size
SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
# Heuristic limits. They flag frames for review and still need tuning on field captures.
QUALITY = {"min_side": 480, "min_sharpness": 25.0, "max_glare": .25, "max_dark": .6}
# Whole-frame result with at least DENSE_COUNT animals whose median box side is below
# SMALL_SIDE px switches to tiles sized so that animals appear about TARGET_SIDE px.
DENSE_COUNT, SMALL_SIDE, TARGET_SIDE = 15, 40, 36
PALETTE = [(230, 57, 70), (42, 157, 143), (244, 162, 97), (69, 123, 157), (155, 93, 229),
           (0, 187, 249), (254, 228, 64), (241, 91, 181), (0, 245, 212), (255, 127, 17)]


def resized(image, limit):
    scale = min(1, limit / max(image.size))
    if scale < 1:
        image = image.resize((round(image.width * scale), round(image.height * scale)),
                             Image.Resampling.BILINEAR)
    return image, scale


def quality(image, original_min_side):
    gray = np.asarray(image.convert("L"), dtype=np.float32)
    tensor = torch.from_numpy(gray)[None, None]
    kernel = torch.tensor([[0, 1, 0], [1, -4, 1], [0, 1, 0]], dtype=torch.float32)[None, None]
    sharpness = float(F.conv2d(tensor, kernel).var())
    glare = float((gray >= 250).mean())
    dark = float((gray <= 25).mean())
    reasons = []
    if original_min_side < QUALITY["min_side"]:
        reasons.append("low_resolution")
    if sharpness < QUALITY["min_sharpness"]:
        reasons.append("blurry")
    if glare > QUALITY["max_glare"]:
        reasons.append("glare")
    if dark > QUALITY["max_dark"]:
        reasons.append("too_dark")
    return {"sharpness": round(sharpness, 1), "glare": round(glare, 4), "dark": round(dark, 4),
            "valid": not reasons, "reasons": reasons}


class Detector:
    """Returns boxes [N, 4], scores [N] and per-instance masks cropped to their box."""

    def __init__(self, folder, device=None):
        self.config = json.loads((folder / "config.json").read_text())
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        # 300 per pass bounds memory: full-size masks are pasted for every detection.
        self.model = build(detections=300)
        self.model.load_state_dict(torch.load(folder / "detect.pt", map_location="cpu", weights_only=True))
        self.model.to(self.device).eval()
        self.version = folder.name

    @torch.no_grad()
    def whole(self, image, threshold):
        tensor = torch.from_numpy(np.asarray(image)).permute(2, 0, 1).float().div(255).to(self.device)
        with torch.autocast(self.device, enabled=self.device == "cuda"):
            output = self.model([tensor])[0]
        keep = output["scores"] >= threshold
        boxes = output["boxes"][keep].float().cpu()
        masks = (output["masks"][keep, 0] >= .5).cpu().numpy()
        crops = []
        for box, mask in zip(boxes.round().int().tolist(), masks):
            x0, y0 = max(0, box[0]), max(0, box[1])
            crops.append((x0, y0, mask[y0:box[3] + 1, x0:box[2] + 1].copy()))
        return boxes, output["scores"][keep].float().cpu(), crops

    def tiled(self, image, threshold, tile, overlap):
        width, height = image.size
        step = tile - overlap
        xs = sorted({min(x, max(0, width - tile)) for x in range(0, max(1, width - overlap), step)})
        ys = sorted({min(y, max(0, height - tile)) for y in range(0, max(1, height - overlap), step)})
        boxes, scores, crops = [], [], []
        for y in ys:
            for x in xs:
                part = image.crop((x, y, min(width, x + tile), min(height, y + tile)))
                b, s, c = self.whole(part, threshold)
                # A tile owns detections centred outside its overlap margin (image borders excepted).
                cx, cy = (b[:, 0] + b[:, 2]) / 2, (b[:, 1] + b[:, 3]) / 2
                own = ((cx >= overlap / 2) | (x == 0)) & ((cx < part.width - overlap / 2) | (x + tile >= width)) \
                    & ((cy >= overlap / 2) | (y == 0)) & ((cy < part.height - overlap / 2) | (y + tile >= height))
                offset = torch.tensor([x, y, x, y], dtype=torch.float32)
                for i in own.nonzero().flatten().tolist():
                    boxes.append(b[i] + offset)
                    scores.append(s[i])
                    crops.append((c[i][0] + x, c[i][1] + y, c[i][2]))
        if not boxes:
            return torch.zeros((0, 4)), torch.zeros(0), []
        boxes, scores = torch.stack(boxes), torch.stack(scores)
        keep = nms(boxes, scores, .5).tolist()
        return boxes[keep], scores[keep], [crops[i] for i in keep]

    def __call__(self, original, threshold=None, mode="auto"):
        """Returns (image used, scale to original, mode used, boxes, scores, crops)."""
        threshold = self.config["threshold"] if threshold is None else threshold
        image, scale = resized(original, MAX_SIDE)
        boxes, scores, crops = self.whole(image, threshold)
        sides = (boxes[:, 2:] - boxes[:, :2]).max(1).values if len(boxes) else torch.zeros(0)
        dense = len(boxes) >= DENSE_COUNT and float(sides.median()) < SMALL_SIDE
        if mode == "whole" or (mode == "auto" and not dense):
            return image, scale, "whole", boxes, scores, crops
        big, big_scale = resized(original, TILE_MAX_SIDE)
        median = float(sides.median()) / scale * big_scale if len(boxes) else SMALL_SIDE
        # The model enlarges each tile to about 800 px on its short side.
        tile = int(min(1024, max(256, 800 * median / TARGET_SIDE)))
        boxes, scores, crops = self.tiled(big, threshold, tile, overlap=max(48, int(2.5 * median)))
        return big, big_scale, f"tiled-{tile}", boxes, scores, crops


class LiteDetector(Detector):
    """ShrimpLite, the phone-sized model, behind the same interface as the reference detector."""

    def __init__(self, folder, device=None):
        self.config = json.loads((folder / "config.json").read_text())
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.model = lite.ShrimpLite()
        self.model.load_state_dict(torch.load(folder / "lite.pt", map_location="cpu", weights_only=True))
        self.model.to(self.device).eval()
        self.version = folder.name

    @torch.no_grad()
    def whole(self, image, threshold):
        scale = self.config["long_side"] / max(image.size)
        size_hw = [round(image.height * scale), round(image.width * scale)]
        tensor = torch.from_numpy(np.asarray(image)).permute(2, 0, 1).float().div(255)[None]
        tensor = F.interpolate(tensor, size=size_hw, mode="bilinear", align_corners=False)
        tensor = F.pad(tensor, [0, -size_hw[1] % 32, 0, -size_hw[0] % 32], value=.45)
        with torch.autocast(self.device, enabled=self.device == "cuda"):
            output = self.model(tensor.to(self.device))[0].float().cpu()
        scores, items = lite.decode(output, threshold, kernel=self.config.get("kernel", 3))
        cell = lite.STRIDE / scale  # one output cell in image pixels
        boxes, crops = [], []
        for x, y, mask in items:
            x0, y0 = round(x * cell), round(y * cell)
            big = np.asarray(Image.fromarray(mask).resize(
                (max(1, round(mask.shape[1] * cell)), max(1, round(mask.shape[0] * cell))), Image.Resampling.NEAREST))
            big = big[:image.height - y0, :image.width - x0]
            boxes.append([x0, y0, x0 + big.shape[1], y0 + big.shape[0]])
            crops.append((x0, y0, big))
        order = scores.argsort(descending=True).tolist()
        return (torch.tensor(boxes, dtype=torch.float32).reshape(-1, 4)[order], scores[order],
                [crops[i] for i in order])


CANONICAL_SIDE = 2048  # rectified tray image, 2048 x 1536
FIRST_PASS_SIDE = 1024
SMALL_ANIMAL = 96      # median body box side (px in the first pass) below which the frame is re-run at full size


class PhoneDetector(Detector):
    """The exported phone model (one ONNX file) run exactly as the app will run it.

    Pass 1 sees the canonical image at half size (1024 long side). When the animals it finds
    are small, pass 2 runs the same file on the full canonical image (2048 long side) and its
    result replaces pass 1. Grouping into animals is `lite.decode`, the reference for app code.
    """

    def __init__(self, folder, device=None, threads=None):
        import onnxruntime as ort
        self.config = json.loads((folder / "config.json").read_text())
        self.device = "cpu"
        options = ort.SessionOptions()
        if threads:
            options.intra_op_num_threads = threads
        self.session = ort.InferenceSession(str(folder / self.config["file"]), options,
                                            providers=["CPUExecutionProvider"])
        self.version = folder.name

    def whole(self, image, threshold, long_side=FIRST_PASS_SIDE):
        scale = long_side / max(image.size)
        small = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.BILINEAR)
        height, width = -(-small.height // 32) * 32, -(-small.width // 32) * 32
        tensor = np.full((1, 3, height, width), .45, np.float32)
        tensor[0, :, :small.height, :small.width] = np.asarray(small, np.float32).transpose(2, 0, 1) / 255
        output = torch.from_numpy(self.session.run(None, {"rgb": tensor})[0][0])
        scores, items = lite.decode(output, threshold, kernel=self.config.get("kernel", 3))
        cell = lite.STRIDE / scale  # one output cell in image pixels
        boxes, crops = [], []
        for x, y, mask in items:
            x0, y0 = round(x * cell), round(y * cell)
            big = np.asarray(Image.fromarray(mask).resize(
                (max(1, round(mask.shape[1] * cell)), max(1, round(mask.shape[0] * cell))), Image.Resampling.NEAREST))
            big = big[:image.height - y0, :image.width - x0]
            boxes.append([x0, y0, x0 + big.shape[1], y0 + big.shape[0]])
            crops.append((x0, y0, big))
        order = scores.argsort(descending=True).tolist()
        return (torch.tensor(boxes, dtype=torch.float32).reshape(-1, 4)[order], scores[order],
                [crops[i] for i in order])

    def __call__(self, original, threshold=None, mode="auto"):
        threshold = self.config["threshold"] if threshold is None else threshold
        image, scale = resized(original, CANONICAL_SIDE)
        boxes, scores, crops = self.whole(image, threshold)
        sides = (boxes[:, 2:] - boxes[:, :2]).max(1).values * FIRST_PASS_SIDE / max(image.size)
        # A second pass needs real extra pixels: enlarging a small photo adds none.
        small = len(boxes) > 0 and float(sides.median()) < SMALL_ANIMAL and max(image.size) >= 1.25 * FIRST_PASS_SIDE
        if mode == "whole" or (mode == "auto" and not small):
            return image, scale, "pass1-1024", boxes, scores, crops
        if mode == "full":  # one pass on the whole canonical image: about twice the memory of tiles
            boxes, scores, crops = self.whole(image, threshold, max(image.size))
            return image, scale, f"pass2-full-{max(image.size)}", boxes, scores, crops
        boxes, scores, crops = self.quarters(image, threshold)
        return image, scale, "pass2-4tiles", boxes, scores, crops

    def quarters(self, image, threshold):
        """Full resolution in four overlapping tiles (1152 x 864 on the canonical image), which
        keeps memory near that of pass 1. Each tile keeps the animals centred in its own quarter;
        the overlap (256 x 192 px) is wider than any animal that triggers this pass."""
        width, height = image.size
        tile_w, tile_h = -(-round(width * .5625) // 32) * 32, -(-round(height * .5625) // 32) * 32
        boxes, scores, crops = [], [], []
        for y in (0, height - tile_h):
            for x in (0, width - tile_w):
                part = image.crop((x, y, x + tile_w, y + tile_h))
                b, s, c = self.whole(part, threshold, max(part.size))
                cx, cy = (b[:, 0] + b[:, 2]) / 2 + x, (b[:, 1] + b[:, 3]) / 2 + y
                own = ((cx < width / 2) == (x == 0)) & ((cy < height / 2) == (y == 0))
                offset = torch.tensor([x, y, x, y], dtype=torch.float32)
                for i in own.nonzero().flatten().tolist():
                    boxes.append(b[i] + offset)
                    scores.append(s[i])
                    crops.append((c[i][0] + x, c[i][1] + y, c[i][2]))
        if not boxes:
            return torch.zeros((0, 4)), torch.zeros(0), []
        boxes, scores = torch.stack(boxes), torch.stack(scores)
        keep = nms(boxes, scores, .5).tolist()  # an animal on a quarter line can be claimed twice
        return boxes[keep], scores[keep], [crops[i] for i in keep]


def load_detector(folder, device=None):
    if (folder / "shrimp-lite.onnx").exists():
        return PhoneDetector(folder)
    return (LiteDetector if (folder / "lite.pt").exists() else Detector)(folder, device)


def draw(image, boxes, crops, title):
    canvas = np.asarray(image).astype(np.float32)
    for i, (x, y, mask) in enumerate(crops):
        color = np.array(PALETTE[i % len(PALETTE)], np.float32)
        region = canvas[y:y + mask.shape[0], x:x + mask.shape[1]]
        mask = mask[:region.shape[0], :region.shape[1]]
        eroded = -F.max_pool2d(-torch.from_numpy(mask)[None, None].float(), 3, 1, 1)
        inner = (eroded[0, 0] > .5).numpy()
        region[mask] = region[mask] * .55 + color * .45
        region[mask & ~inner] = 255
    result = Image.fromarray(canvas.astype(np.uint8))
    pen = ImageDraw.Draw(result)
    size = max(12, round(max(result.size) / 70))
    font = ImageFont.load_default(size=size)
    for i, box in enumerate(boxes.tolist()):
        pen.rectangle(box, outline=PALETTE[i % len(PALETTE)], width=max(1, size // 10))
        if len(boxes) <= 80:
            pen.text((box[0] + 2, box[1] + 1), str(i + 1), fill=(255, 255, 255), font=font,
                     stroke_width=2, stroke_fill=(0, 0, 0))
    header = ImageFont.load_default(size=size * 2)
    pen.text((12, 10), title, fill=(255, 255, 255), font=header, stroke_width=3, stroke_fill=(0, 0, 0))
    return result


def gut_summary(instances):
    """Experimental: share of animals whose gut can be read, and their mean fullness index."""
    values = [item["gut"]["index"] for item in instances if item["gut"]["index"] is not None]
    if not values:
        return {"observable_share": 0.0, "index_mean": None, "status": "experimental, not validated"}
    levels = [item["gut"]["level"] for item in instances if item["gut"]["index"] is not None]
    return {"observable_share": round(len(values) / len(instances), 2), "index_mean": round(float(np.mean(values)), 2),
            "levels": {name: levels.count(name) for name in ("empty", "partial", "full")},
            "status": "experimental, not validated"}


def analyse(paths, detector, output=None, threshold=None, mode="auto", px_per_cm=None, table=None):
    frames = []
    for path in paths:
        started = time.perf_counter()
        original = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
        check = quality(resized(original, MAX_SIDE)[0], min(original.size))
        image, scale, used_mode, boxes, scores, crops = detector(original, threshold, mode)
        instances = []
        pixels = np.asarray(image)
        for i, (box, score, crop) in enumerate(zip(boxes, scores, crops)):
            length, width = (value / scale for value in size.measure(crop[2]))
            # Animals cut by the frame edge are counted but not measured.
            edge = box[0] <= 2 or box[1] <= 2 or box[2] >= image.width - 2 or box[3] >= image.height - 2
            item = {"id": i + 1, "score": round(float(score), 3),
                    "box_xyxy": [round(float(v) / scale, 1) for v in box],
                    "area_px": round(float(crop[2].sum()) / scale ** 2),
                    "length_px": round(length, 1), "width_px": round(width, 1), "touches_edge": bool(edge)}
            if px_per_cm and not edge and length > 0:
                item["length_cm"] = round(length / px_per_cm, 2)
                item["width_cm"] = round(width / px_per_cm, 2)
                item["weight_g"] = round(size.weight_from_length(length / px_per_cm, table)[0], 3)
            x, y, mask = crop
            view = pixels[y:y + mask.shape[0], x:x + mask.shape[1]]
            item["gut"] = {"index": None, "level": "not_observable", "reason": "touches_edge"} if edge                 else gut.gut_fullness(view, mask[:view.shape[0], :view.shape[1]])
            instances.append(item)
        frames.append({"file": Path(path).name, "quality": check, "mode": used_mode,
                       "count": len(instances), "instances": instances,
                       "gut": gut_summary(instances),
                       "size": size.summarise([item["length_cm"] for item in instances
                                               if "length_cm" in item], table),
                       "seconds": round(time.perf_counter() - started, 3),
                       "_draw": (image, boxes, crops)})
    valid = [frame for frame in frames if frame["quality"]["valid"]]
    used = valid or frames
    mean = float(np.mean([frame["count"] for frame in used]))
    representative = min(used, key=lambda f: (abs(f["count"] - mean), -f["quality"]["sharpness"]))
    result = {
        "status": "ok" if valid else "retake_suggested",
        "count": round(mean), "count_mean": round(mean, 2),
        "count_per_frame": [frame["count"] for frame in frames],
        "frames_total": len(frames), "frames_valid": len(valid),
        "representative_frame": representative["file"],
        # Species needs its own classifier trained on both species under matched capture conditions.
        "species": "undetermined",
        "detector": {"version": detector.version, "device": detector.device,
                     "threshold": detector.config["threshold"] if threshold is None else threshold},
        "size": None,
        "units": "Pixel values refer to the original image. Sizes in cm and g appear only when "
                 "--px-per-cm is given; the scale itself comes from the calibration step.",
        "frames": [{k: v for k, v in frame.items() if k != "_draw"} for frame in frames],
    }
    guts = [frame["gut"]["index_mean"] for frame in used if frame["gut"]["index_mean"] is not None]
    result["gut"] = {"index_mean": round(float(np.mean(guts)), 2) if guts else None,
                     "observable_share": round(float(np.mean([frame["gut"]["observable_share"] for frame in used])), 2),
                     "status": "experimental, not validated"}
    sized = [frame["size"] for frame in used if frame["size"]]
    if sized:
        result["size"] = {"table": sized[0]["table"], "frames_used": len(sized),
                          **{key: round(float(np.mean([item[key] for item in sized])), 3)
                             for key in ("length_cm_mean", "length_cm_cv_percent", "weight_g_mean", "count_per_kg")},
                          "source": "length -> weight table; species is not estimated"}
    if output:
        output.mkdir(parents=True, exist_ok=True)
        image, boxes, crops = representative["_draw"]
        draw(image, boxes, crops, f"{result['count']} con").save(output / "overlay.jpg", quality=90)
        labels = np.zeros(image.size[::-1], np.uint16)
        for i, (x, y, mask) in enumerate(crops):
            region = labels[y:y + mask.shape[0], x:x + mask.shape[1]]
            region[mask[:region.shape[0], :region.shape[1]]] = i + 1
        Image.fromarray(labels).save(output / "instances.png")
        (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--model", type=Path, default=ROOT / "artifacts/detect-v3")
    parser.add_argument("--threshold", type=float)
    parser.add_argument("--mode", choices=["auto", "whole", "tiled"], default="auto")
    parser.add_argument("--px-per-cm", type=float, help="original-image pixels per cm on the tray floor")
    parser.add_argument("--table", choices=["average", *sorted(size.TABLES["tables"])],
                        help="length-to-weight ruler; default is the average of both rulers")
    args = parser.parse_args()
    paths = sorted(p for p in args.input.iterdir() if p.suffix.lower() in SUFFIXES) \
        if args.input.is_dir() else [args.input]
    if not paths:
        sys.exit("No images found.")
    output = args.output or ROOT / "artifacts/runs" / args.input.stem
    result = analyse(paths, load_detector(args.model), output, args.threshold, args.mode, args.px_per_cm, args.table)
    summary = {k: result[k] for k in ("status", "count", "count_per_frame", "frames_valid",
                                      "representative_frame", "species", "size", "gut")}
    summary["mode"] = [frame["mode"] for frame in result["frames"]]
    print(json.dumps(summary, ensure_ascii=False))
    print("Saved:", output)


if __name__ == "__main__":
    main()
