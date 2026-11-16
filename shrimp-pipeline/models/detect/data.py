"""Instance data for the tray detector: loading, splits and augmentation."""
import io
import json
import math
import random
import re
import tarfile
from collections import defaultdict
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import torch

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data/raw"
MAX_SIDE = 1280


def split_groups(groups):
    """Same grouped split as count-v1 so both models share held-out images."""
    keys = sorted(set(groups))
    random.Random(37).shuffle(keys)
    size = max(1, round(len(keys) * .15))
    return {key: ("test" if i < size else "val" if i < 2 * size else "train")
            for i, key in enumerate(keys)}


def load_csiro():
    rows = []
    with tarfile.open(RAW / "csiro-black-tiger-v1.tar") as source:
        prefix = "black_tiger_prawn_coco_instance_dataset/"
        coco = json.load(source.extractfile(prefix + "annotations/all_annotations.json"))
        polygons = defaultdict(list)
        for item in coco["annotations"]:
            if not item.get("iscrowd"):
                polygons[item["image_id"]].append(item["segmentation"])
        # Images without annotations are excluded: their empty status is unverified.
        images = [item for item in coco["images"] if polygons[item["id"]]]
        groups = split_groups(item["file_name"].split("_")[0] for item in images)
        for item in images:
            name = item["file_name"]
            rows.append({"source": "csiro", "species": "monodon", "name": name,
                         "split": groups[name.split("_")[0]],
                         "image": source.extractfile(prefix + "images/" + name).read(),
                         "polygons": polygons[item["id"]]})
    return rows


def load_vannamei():
    rows = []
    with ZipFile(RAW / "vannamei-anatomical-v1.zip") as source:
        names = [name for name in source.namelist() if re.search(r"_frame\d+\.png$", name)]
        groups = split_groups(name.split("/")[-2] for name in names)
        for name in names:
            mask_name = re.sub(r"_frame\d+\.png$", "_mask_full.png", name)
            rows.append({"source": "vannamei", "species": "vannamei", "name": name,
                         "split": groups[name.split("/")[-2]],
                         "image": source.read(name), "mask_png": source.read(mask_name)})
    return rows


# Roboflow Universe exports used for training. Each entry: file stem, source tag, species,
# kept classes, split policy. "roboflow" keeps the publisher's split; a string names a joint
# grouped split so the same photo in two projects stays in one split; "train" is train-only.
ROBOFLOW = [
    ("jala-apjmn--vannamei-shrimp-v8-coco-segmentation", "jala", "vannamei",
     {"top_shrimp", "side_shrimp"}, "roboflow"),
    ("thenho--shrimp-size-v3-coco-segmentation", "thenho", "unknown", {"shrimp"}, "thenho"),
    ("thenho--shrimpsizefromcameraclaibration-v2-coco-segmentation", "thenho", "unknown", {"shrimp"}, "thenho"),
    ("thenho--img-smkzh-v10-coco-segmentation", "thenho-pond", "unknown", {"shrimp"}, "train"),
]


def load_roboflow():
    rows, pending = [], defaultdict(list)
    for stem, tag, species, classes, policy in ROBOFLOW:
        path = RAW / "roboflow" / f"{stem}.zip"
        if not path.exists():
            print("missing", path.name, flush=True)
            continue
        with ZipFile(path) as source:
            for part in ("train", "valid", "test"):
                name = f"{part}/_annotations.coco.json"
                if name not in source.namelist():
                    continue
                coco = json.loads(source.read(name))
                keep = {c["id"] for c in coco["categories"] if c["name"].lower() in classes}
                polygons = defaultdict(list)
                for item in coco["annotations"]:
                    if item["category_id"] in keep and not item.get("iscrowd"):
                        shape = item.get("segmentation")
                        if isinstance(shape, list) and shape:  # whole-body polygons only
                            polygons[item["image_id"]].append(shape)
                for item in coco["images"]:
                    if not polygons[item["id"]]:
                        continue  # no kept class: empty status of the tray is unverified
                    row = {"source": tag, "species": species, "name": f"{stem}/{part}/{item['file_name']}",
                           "group": item["file_name"].split(".rf.")[0], "part": part,
                           "image": source.read(f"{part}/{item['file_name']}"),
                           "polygons": polygons[item["id"]]}
                    if policy == "roboflow":
                        row["split"] = {"valid": "val"}.get(part, part)
                        rows.append(row)
                    elif policy == "train":
                        row["split"] = "train"
                        rows.append(row)
                    else:
                        pending[policy].append(row)
    for group_rows in pending.values():
        splits = split_groups(row["group"] for row in group_rows)
        seen = set()
        # Held-out groups keep one copy, preferring the publisher's unaugmented valid/test image.
        for row in sorted(group_rows, key=lambda r: r["part"] == "train"):
            row["split"] = splits[row["group"]]
            if row["split"] != "train":
                if row["group"] in seen:
                    continue
                seen.add(row["group"])
            rows.append(row)
    return rows


def load_rows():
    return load_csiro() + load_vannamei() + load_roboflow()


def decode(row):
    """Return RGB uint8 image and a bool mask stack [N, H, W], long side <= MAX_SIDE."""
    image = Image.open(io.BytesIO(row["image"])).convert("RGB")
    scale = min(1, MAX_SIDE / max(image.size))
    size = (round(image.width * scale), round(image.height * scale))
    masks = []
    if "polygons" in row:
        for parts in row["polygons"]:
            canvas = Image.new("L", size)
            draw = ImageDraw.Draw(canvas)
            for part in parts:
                if len(part) >= 6:
                    draw.polygon([value * scale for value in part], fill=255)
            masks.append(np.asarray(canvas) > 0)
    else:
        mask = Image.open(io.BytesIO(row["mask_png"])).convert("L")
        masks.append(np.asarray(mask.resize(size, Image.Resampling.NEAREST)) > 127)
    if scale < 1:
        image = image.resize(size, Image.Resampling.BILINEAR)
    return np.asarray(image), np.stack(masks)


def cutouts(rows, limit=160):
    """RGBA crops of single vannamei animals for copy-paste augmentation."""
    result = []
    for row in rows:
        if row["source"] != "vannamei" or row["split"] != "train":
            continue
        image, masks = decode(row)
        ys, xs = np.nonzero(masks[0])
        if len(xs) < 200:
            continue
        box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        alpha = Image.fromarray((masks[0] * 255).astype(np.uint8)).crop(box)
        alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1))
        crop = Image.fromarray(image).crop(box).convert("RGBA")
        crop.putalpha(alpha)
        crop.thumbnail((limit * 2, limit * 2))
        result.append(crop)
    return result


def paste(image, masks, pool, count, length_range):
    """Paste `count` cutouts; later pastes occlude earlier instances."""
    canvas = Image.fromarray(image)
    masks = list(masks)
    height, width = image.shape[:2]
    for _ in range(count):
        crop = random.choice(pool)
        length = random.uniform(*length_range)
        ratio = length / max(crop.size)
        crop = crop.resize((max(4, round(crop.width * ratio)), max(4, round(crop.height * ratio))),
                           Image.Resampling.BILINEAR)
        crop = crop.rotate(random.uniform(0, 360), expand=True, resample=Image.Resampling.BILINEAR)
        if random.random() < .5:
            crop = crop.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if crop.width >= width or crop.height >= height:
            continue
        x = random.randint(0, width - crop.width)
        y = random.randint(0, height - crop.height)
        canvas.paste(crop, (x, y), crop)
        new = np.zeros((height, width), bool)
        new[y:y + crop.height, x:x + crop.width] = np.asarray(crop.getchannel("A")) > 127
        masks = [mask & ~new for mask in masks] + [new]
    return np.asarray(canvas), masks


def synthetic_tray(pool):
    """A light tray-like background with many pasted animals."""
    height, width = random.choice([(720, 960), (960, 720), (720, 1280), (1280, 720)])
    base = np.array([random.randint(150, 250)] * 3, np.float32) + np.random.uniform(-18, 18, 3)
    ys, xs = np.mgrid[0:height, 0:width].astype(np.float32)
    angle = random.uniform(0, 2 * math.pi)
    shade = (math.cos(angle) * xs / width + math.sin(angle) * ys / height) * random.uniform(0, 45)
    image = base[None, None] + shade[..., None] + np.random.normal(0, random.uniform(2, 8), (height, width, 3))
    image = np.clip(image, 0, 255).astype(np.uint8)
    dense = random.random() < .5
    count = random.randint(15, 60) if dense else random.randint(1, 12)
    lengths = (45, 130) if dense else (120, 420)
    image, masks = paste(image, [], pool, count, lengths)
    return image, masks


class TrayDataset(torch.utils.data.Dataset):
    def __init__(self, rows, pool=None, train=False, synthetic=0):
        self.rows, self.pool, self.train, self.synthetic = rows, pool or [], train, synthetic

    def __len__(self):
        return len(self.rows) + self.synthetic

    def __getitem__(self, index):
        if index >= len(self.rows):
            image, masks = synthetic_tray(self.pool)
        else:
            image, masks = decode(self.rows[index])
            masks = list(masks)
            if self.train and self.pool and random.random() < .35:
                image, masks = paste(image, masks, self.pool, random.randint(1, 6), (70, 260))
        masks = np.stack(masks) if len(masks) else np.zeros((0, *image.shape[:2]), bool)
        if self.train:
            image, masks = augment(image, masks)
        keep, boxes = [], []
        for i, mask in enumerate(masks):
            ys, xs = np.nonzero(mask)
            if len(xs) >= 6 and xs.max() - xs.min() >= 2 and ys.max() - ys.min() >= 2:
                keep.append(i)
                boxes.append([xs.min(), ys.min(), xs.max() + 1, ys.max() + 1])
        target = {"boxes": torch.tensor(boxes, dtype=torch.float32).reshape(-1, 4),
                  "labels": torch.ones(len(keep), dtype=torch.int64),
                  "masks": torch.from_numpy(masks[keep].astype(np.uint8))}
        tensor = torch.from_numpy(np.ascontiguousarray(image)).permute(2, 0, 1).float() / 255
        return tensor, target


def augment(image, masks):
    if random.random() < .5:
        image, masks = image[:, ::-1], masks[:, :, ::-1]
    if random.random() < .5:
        image, masks = image[::-1], masks[:, ::-1]
    turns = random.randint(0, 3)  # top-down trays have no fixed orientation
    image, masks = np.rot90(image, turns), np.rot90(masks, turns, axes=(1, 2))
    gain = np.random.uniform(.75, 1.25, 3) * random.uniform(.8, 1.2)
    image = np.clip(image.astype(np.float32) * gain + random.uniform(-20, 20), 0, 255).astype(np.uint8)
    return image, masks


def collate(batch):
    return tuple(zip(*batch))
