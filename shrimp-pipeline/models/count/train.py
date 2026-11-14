"""Train and export a compact, single-class center detector."""
import argparse
import csv
import io
import json
import random
import re
import tarfile
from collections import defaultdict
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from PIL import Image
import torch
from torch import nn
from torch.nn import functional as F
from torchvision.models import mobilenet_v3_small

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data/raw"
WIDTH, HEIGHT, STRIDE = 384, 224, 8
MEAN = np.array([.485, .456, .406], dtype=np.float32)
STD = np.array([.229, .224, .225], dtype=np.float32)


def split_groups(groups):
    keys = sorted(set(groups))
    random.Random(37).shuffle(keys)
    size = max(1, round(len(keys) * .15))
    return {key: ("test" if i < size else "val" if i < 2 * size else "train")
            for i, key in enumerate(keys)}


def load_rows():
    rows = []
    with tarfile.open(RAW / "csiro-black-tiger-v1.tar") as source:
        prefix = "black_tiger_prawn_coco_instance_dataset/"
        coco = json.load(source.extractfile(prefix + "annotations/all_annotations.json"))
        boxes = defaultdict(list)
        for item in coco["annotations"]:
            if not item.get("iscrowd"):
                boxes[item["image_id"]].append(item["bbox"])
        # Include annotated images only. The archive includes images with no
        # annotations, whose negative status has not been verified.
        images = [item for item in coco["images"] if boxes[item["id"]]]
        groups = split_groups(item["file_name"].split("_")[0] for item in images)
        for item in images:
            name = item["file_name"]
            rows.append(("csiro", name, groups[name.split("_")[0]],
                         source.extractfile(prefix + "images/" + name).read(), boxes[item["id"]]))
    with ZipFile(RAW / "vannamei-anatomical-v1.zip") as source:
        names = [name for name in source.namelist() if re.search(r"_frame\d+\.png$", name)]
        groups = split_groups(name.split("/")[-2] for name in names)
        for name in names:
            mask_name = re.sub(r"_frame\d+\.png$", "_mask_full.png", name)
            mask = Image.open(io.BytesIO(source.read(mask_name))).convert("L")
            left, top, right, bottom = mask.getbbox()
            rows.append(("vannamei", name, groups[name.split("/")[-2]], source.read(name),
                         [[left, top, right - left, bottom - top]]))
    return rows


def prepare(raw):
    img = Image.open(io.BytesIO(raw)).convert("RGB")
    scale = min(WIDTH / img.width, HEIGHT / img.height)
    size = (round(img.width * scale), round(img.height * scale))
    pad = ((WIDTH - size[0]) // 2, (HEIGHT - size[1]) // 2)
    canvas = Image.new("RGB", (WIDTH, HEIGHT), (114,) * 3)
    canvas.paste(img.resize(size, Image.Resampling.BILINEAR), pad)
    x = ((np.asarray(canvas, dtype=np.float32) / 255 - MEAN) / STD).transpose(2, 0, 1)
    return x, scale, pad


class Dataset(torch.utils.data.Dataset):
    def __init__(self, rows, augment=False):
        self.rows = rows
        self.augment = augment

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, i):
        _, _, _, raw, boxes = self.rows[i]
        x, scale, (px, py) = prepare(raw)
        label = np.zeros((1, HEIGHT // STRIDE, WIDTH // STRIDE), np.float32)
        flip = self.augment and random.random() < .5
        for bx, by, w, h in boxes:
            center_x = (bx + w / 2) * scale + px
            if flip:
                center_x = WIDTH - center_x
            gx = min(label.shape[2] - 1, max(0, int(center_x / STRIDE)))
            gy = min(label.shape[1] - 1, max(0, int(((by + h / 2) * scale + py) / STRIDE)))
            label[0, gy, gx] = 1
        if flip:
            x = x[:, :, ::-1].copy()
        return x, label


class CountModel(nn.Module):
    def __init__(self, pretrained=False):
        super().__init__()
        base = mobilenet_v3_small()
        if pretrained:
            path = ROOT / "checkpoints/pretrained/mobilenet-v3-small-imagenet1k-v1.pth"
            base.load_state_dict(torch.load(path, map_location="cpu", weights_only=True))
        self.detail = base.features[:4]  # stride 8
        self.context = base.features[4:9]  # stride 16
        self.head = nn.Sequential(nn.Conv2d(72, 24, 3, padding=1), nn.BatchNorm2d(24),
                                  nn.ReLU(), nn.Conv2d(24, 1, 1))
        nn.init.constant_(self.head[-1].bias, -4)

    def forward(self, x):
        detail = self.detail(x)
        context = F.interpolate(self.context(detail), scale_factor=2, mode="nearest")
        return self.head(torch.cat((detail, context), dim=1))


def peaks(logits, threshold):
    scores = torch.as_tensor(logits).sigmoid()
    local = F.max_pool2d(scores, 3, stride=1, padding=1)
    return ((scores >= threshold) & (scores == local)).nonzero().tolist()


def evaluate(model, rows, device, thresholds):
    by_threshold = {value: [] for value in thresholds}
    loader = torch.utils.data.DataLoader(Dataset(rows), batch_size=32)
    model.eval()
    offset = 0
    with torch.no_grad():
        for inputs, _ in loader:
            logits = model(inputs.to(device)).cpu()
            for image in logits:
                actual = len(rows[offset][4])
                for threshold in thresholds:
                    by_threshold[threshold].append(len(peaks(image[None], threshold)) - actual)
                offset += 1
    return {threshold: float(np.mean(np.abs(errors))) for threshold, errors in by_threshold.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=12)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/count-v1")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(4)
    random.seed(37)
    torch.manual_seed(37)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    rows = load_rows()
    train, val = ([row for row in rows if row[2] == split] for split in ("train", "val"))
    with (args.output / "split.csv").open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["source", "image", "split", "label_count"])
        writer.writerows((a, b, c, len(e)) for a, b, c, _, e in rows)
    loader = torch.utils.data.DataLoader(Dataset(train, True), batch_size=24, shuffle=True,
                                         num_workers=2, persistent_workers=True)
    model = CountModel(pretrained=True).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=.0015)
    best = float("inf")
    history = []
    for epoch in range(args.epochs):
        model.train()
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            optimizer.zero_grad()
            logits = model(x)
            prob = logits.sigmoid()
            loss = F.binary_cross_entropy_with_logits(logits, y, reduction="none")
            focal = torch.where(y == 1, (1 - prob).square(), prob.square())
            ((loss * focal).sum() / y.sum().clamp(min=1)).backward()
            optimizer.step()
        scores = evaluate(model, val, device, [.10, .15, .20, .25, .30, .35, .4, .5, .6])
        threshold = min(scores, key=scores.get)
        history.append({"epoch": epoch + 1, "validation_mae": scores[threshold], "threshold": threshold})
        print(history[-1], flush=True)
        if scores[threshold] < best:
            best = scores[threshold]
            torch.save(model.state_dict(), args.output / "count.pt")
            (args.output / "config.json").write_text(json.dumps({
                "threshold": threshold, "width": WIDTH, "height": HEIGHT, "stride": STRIDE,
                "mean_rgb": MEAN.tolist(), "std_rgb": STD.tolist(), "letterbox_fill": 114,
                "device": device,
            }, indent=2))
    model.load_state_dict(torch.load(args.output / "count.pt", map_location=device, weights_only=True))
    torch.onnx.export(model.cpu().eval(), torch.zeros(1, 3, HEIGHT, WIDTH),
                      args.output / "count.onnx", input_names=["rgb"], output_names=["logits"],
                      opset_version=17, dynamo=False)
    (args.output / "training.json").write_text(json.dumps(history, indent=2))


if __name__ == "__main__":
    main()
