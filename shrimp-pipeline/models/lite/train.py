"""Train ShrimpLite on the same rows and held-out split as detect-v3."""
import argparse
import json
import random
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np
import torch
from torch.nn import functional as F
from torchvision.ops import box_iou

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "detect"))
from data import ROOT, TrayDataset, cutouts, load_rows  # noqa: E402
from model import STRIDE, ShrimpLite, decode, loss_fn, targets  # noqa: E402

CROP = 768        # training crop
LONG_SIDE = 1024  # reference long side of a whole tray frame at inference
THRESHOLDS = [.2, .3, .4, .5, .6]
KERNEL = 7           # peak window in output cells; 3 splits long animals into pieces
SCALES = (.4, 1.6)   # animals from about 30 px to 500 px long at the model input


class LiteDataset(torch.utils.data.Dataset):
    """Scale-jittered fixed-size crops with ShrimpLite target maps."""

    def __init__(self, rows, pool, synthetic):
        self.base = TrayDataset(rows, pool, True, synthetic)

    def __len__(self):
        return len(self.base)

    def __getitem__(self, index):
        image, target = self.base[index]
        masks = target["masks"].float()
        scale = LONG_SIDE / max(image.shape[1:]) * random.uniform(*SCALES)
        size = [max(32, round(image.shape[1] * scale)), max(32, round(image.shape[2] * scale))]
        image = F.interpolate(image[None], size=size, mode="bilinear", align_corners=False)[0]
        if len(masks):
            masks = F.interpolate(masks[None], size=size, mode="nearest")[0]
        canvas = torch.full((3, CROP, CROP), .45)
        canvas_masks = torch.zeros((len(masks), CROP, CROP))
        top = random.randint(0, max(0, size[0] - CROP))
        left = random.randint(0, max(0, size[1] - CROP))
        h, w = min(CROP, size[0]), min(CROP, size[1])
        canvas[:, :h, :w] = image[:, top:top + h, left:left + w]
        canvas_masks[:, :h, :w] = masks[:, top:top + h, left:left + w]
        heat, body, offset = targets(canvas_masks.numpy() > .5, CROP, CROP)
        return canvas, torch.from_numpy(heat), torch.from_numpy(body), torch.from_numpy(offset)


def prepare(image, long_side=LONG_SIDE):
    """[3, H, W] 0..1 -> resized so the long side is `long_side`, padded to a multiple of 32."""
    scale = long_side / max(image.shape[1:])
    size = [round(image.shape[1] * scale), round(image.shape[2] * scale)]
    image = F.interpolate(image[None], size=size, mode="bilinear", align_corners=False)
    pad = [0, (32 - size[1] % 32) % 32, 0, (32 - size[0] % 32) % 32]
    return F.pad(image, pad, value=.45), scale


def boxes_from(items, scale):
    boxes = [[x * STRIDE / scale, y * STRIDE / scale, (x + mask.shape[1]) * STRIDE / scale,
              (y + mask.shape[0]) * STRIDE / scale] for x, y, mask in items]
    return torch.tensor(boxes, dtype=torch.float32).reshape(-1, 4)


def evaluate(model, rows, device):
    model.eval()
    data = TrayDataset(rows)
    stats = {t: {"abs": [], "tp": 0, "fp": 0, "fn": 0, "by": {}} for t in THRESHOLDS}
    with torch.no_grad():
        for index in range(len(data)):
            image, target = data[index]
            tensor, scale = prepare(image)
            with torch.autocast(device, enabled=device == "cuda"):
                output = model(tensor.to(device))[0].float().cpu()
            truth = target["boxes"]
            for t in THRESHOLDS:
                scores, items = decode(output, t, kernel=KERNEL)
                boxes = boxes_from(items, scale)[scores.argsort(descending=True)] if len(items) else torch.zeros((0, 4))
                tp, used = 0, set()
                if len(boxes) and len(truth):
                    for row in box_iou(boxes, truth):
                        best = max((j for j in range(len(truth)) if j not in used), key=lambda j: row[j], default=None)
                        if best is not None and row[best] >= .5:
                            used.add(best)
                            tp += 1
                s = stats[t]
                s["abs"].append(abs(len(boxes) - len(truth)))
                s["tp"] += tp
                s["fp"] += len(boxes) - tp
                s["fn"] += len(truth) - tp
                s["by"].setdefault(rows[index]["source"], []).append(abs(len(boxes) - len(truth)))
    result = {}
    for t, s in stats.items():
        precision, recall = s["tp"] / max(1, s["tp"] + s["fp"]), s["tp"] / max(1, s["tp"] + s["fn"])
        result[t] = {"count_mae": float(np.mean(s["abs"])), "precision": precision, "recall": recall,
                     "f1": 2 * precision * recall / max(1e-9, precision + recall),
                     "mae_by_source": {k: float(np.mean(v)) for k, v in s["by"].items()}}
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=45)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/lite-v2")
    parser.add_argument("--init", type=Path, help="lite.pt to continue from instead of ImageNet weights")
    parser.add_argument("--lr", type=float, default=1e-3)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    random.seed(37)
    torch.manual_seed(37)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    rows = load_rows()
    print(dict(Counter((row["source"], row["split"]) for row in rows)), flush=True)
    train, val = ([row for row in rows if row["split"] == name] for name in ("train", "val"))
    loader = torch.utils.data.DataLoader(LiteDataset(train, cutouts(rows), 300), batch_size=8, shuffle=True,
                                         num_workers=6, persistent_workers=True, drop_last=True)
    model = ShrimpLite(pretrained=not args.init)
    if args.init:
        model.load_state_dict(torch.load(args.init, map_location="cpu", weights_only=True))
    model.to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    schedule = torch.optim.lr_scheduler.OneCycleLR(optimizer, args.lr, total_steps=args.epochs * len(loader),
                                                   pct_start=.08)
    scaler = torch.amp.GradScaler(enabled=device == "cuda")
    history, best = [], -1
    for epoch in range(args.epochs):
        model.train()
        started, parts = time.time(), []
        for image, heat, body, offset in loader:
            with torch.autocast(device, enabled=device == "cuda"):
                output = model(image.to(device))
            loss, detail = loss_fn(output.float(), heat.to(device), body.to(device), offset.to(device))
            optimizer.zero_grad()
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
            schedule.step()
            parts.append(detail)
        entry = {"epoch": epoch + 1, "loss": [round(float(v), 4) for v in np.mean(parts, 0)],
                 "minutes": round((time.time() - started) / 60, 2)}
        if epoch % 3 == 2 or epoch >= args.epochs - 6:
            scores = evaluate(model, val, device)
            threshold = max(scores, key=lambda t: scores[t]["f1"])
            entry.update(threshold=threshold, **scores[threshold])
            if entry["f1"] > best:
                best = entry["f1"]
                torch.save(model.state_dict(), args.output / "lite.pt")
                (args.output / "config.json").write_text(json.dumps(
                    {"threshold": threshold, "architecture": "ShrimpLite-MobileNetV3-Large",
                     "long_side": LONG_SIDE, "stride": STRIDE, "kernel": KERNEL, "epoch": epoch + 1}, indent=2))
        history.append(entry)
        print(json.dumps(entry), flush=True)
        (args.output / "training.json").write_text(json.dumps(history, indent=2))


if __name__ == "__main__":
    main()
