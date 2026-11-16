"""Fine-tune Mask R-CNN (one class: shrimp) for tray localisation and counting."""
import argparse
import json
import random
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np
import torch
from torchvision.models.detection import maskrcnn_resnet50_fpn_v2
from torchvision.models.detection.faster_rcnn import FastRCNNPredictor
from torchvision.models.detection.mask_rcnn import MaskRCNNPredictor
from torchvision.ops import box_iou

sys.path.insert(0, str(Path(__file__).resolve().parent))
from data import ROOT, TrayDataset, collate, cutouts, load_rows  # noqa: E402

PRETRAINED = ROOT / "checkpoints/pretrained/maskrcnn-resnet50-fpn-v2-coco.pth"
THRESHOLDS = [.3, .4, .5, .6, .7, .8, .9]


def build(pretrained=False, detections=300):
    # Full-size masks are pasted per detection, so the cap also bounds inference memory.
    model = maskrcnn_resnet50_fpn_v2(weights=None, weights_backbone=None,
                                     min_size=(608, 672, 720, 800), max_size=1333,
                                     box_detections_per_img=detections)
    if pretrained:
        model.load_state_dict(torch.load(PRETRAINED, map_location="cpu", weights_only=True))
    model.roi_heads.box_predictor = FastRCNNPredictor(1024, 2)
    model.roi_heads.mask_predictor = MaskRCNNPredictor(256, 256, 2)
    return model


def evaluate(model, rows, device):
    """Count error and box matching (IoU >= .5) per score threshold."""
    model.eval()
    loader = torch.utils.data.DataLoader(TrayDataset(rows), batch_size=2, collate_fn=collate, num_workers=2)
    stats = {t: {"abs": [], "err": [], "tp": 0, "fp": 0, "fn": 0, "by": {}} for t in THRESHOLDS}
    index = 0
    with torch.no_grad():
        for images, targets in loader:
            with torch.autocast(device, enabled=device == "cuda"):
                outputs = model([image.to(device) for image in images])
            for output, target in zip(outputs, targets):
                source = rows[index]["source"]
                index += 1
                truth = target["boxes"]
                for t in THRESHOLDS:
                    boxes = output["boxes"][output["scores"] >= t].float().cpu()
                    tp = 0
                    if len(boxes) and len(truth):
                        iou = box_iou(boxes, truth)
                        used = set()
                        for row in iou:  # predictions are sorted by score
                            best = max((j for j in range(len(truth)) if j not in used),
                                       key=lambda j: row[j], default=None)
                            if best is not None and row[best] >= .5:
                                used.add(best)
                                tp += 1
                    s = stats[t]
                    error = len(boxes) - len(truth)
                    s["abs"].append(abs(error))
                    s["err"].append(error)
                    s["tp"] += tp
                    s["fp"] += len(boxes) - tp
                    s["fn"] += len(truth) - tp
                    s["by"].setdefault(source, []).append(abs(error))
    result = {}
    for t, s in stats.items():
        precision = s["tp"] / max(1, s["tp"] + s["fp"])
        recall = s["tp"] / max(1, s["tp"] + s["fn"])
        result[t] = {"count_mae": float(np.mean(s["abs"])), "count_bias": float(np.mean(s["err"])),
                     "exact": float(np.mean(np.array(s["abs"]) == 0)),
                     "precision": precision, "recall": recall,
                     "f1": 2 * precision * recall / max(1e-9, precision + recall),
                     "mae_by_source": {k: float(np.mean(v)) for k, v in s["by"].items()},
                     "images": len(s["abs"])}
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=14)
    parser.add_argument("--synthetic", type=int, default=250)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/detect-v3")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    random.seed(37)
    torch.manual_seed(37)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    rows = load_rows()
    train, val, test = ([row for row in rows if row["split"] == name] for name in ("train", "val", "test"))
    print(dict(Counter((row["source"], row["split"]) for row in rows)), flush=True)
    (args.output / "split.json").write_text(json.dumps(
        [{k: row[k] for k in ("source", "name", "split")} for row in rows], indent=1))
    pool = cutouts(rows)
    loader = torch.utils.data.DataLoader(TrayDataset(train, pool, True, args.synthetic), batch_size=2,
                                         shuffle=True, collate_fn=collate, num_workers=4,
                                         persistent_workers=True)
    model = build(pretrained=True).to(device)
    params = [p for p in model.parameters() if p.requires_grad]
    optimizer = torch.optim.SGD(params, lr=.01, momentum=.9, weight_decay=1e-4)
    total = args.epochs * len(loader)
    warmup = 300
    schedule = torch.optim.lr_scheduler.LambdaLR(optimizer, lambda step: min(1, (step + 1) / warmup) * (
        1 if step < .65 * total else .1 if step < .9 * total else .01))
    scaler = torch.amp.GradScaler(enabled=device == "cuda")
    history, best = [], -1
    for epoch in range(args.epochs):
        model.train()
        started, running = time.time(), []
        for images, targets in loader:
            images = [image.to(device) for image in images]
            targets = [{k: v.to(device) for k, v in target.items()} for target in targets]
            with torch.autocast(device, enabled=device == "cuda"):
                loss = sum(model(images, targets).values())
            optimizer.zero_grad()
            scaler.scale(loss).backward()
            scaler.unscale_(optimizer)
            torch.nn.utils.clip_grad_norm_(params, 10)
            scaler.step(optimizer)
            scaler.update()
            schedule.step()
            running.append(loss.item())
        scores = evaluate(model, val, device)
        torch.cuda.empty_cache()
        threshold = max(scores, key=lambda t: scores[t]["f1"] - .02 * scores[t]["count_mae"])
        entry = {"epoch": epoch + 1, "loss": float(np.mean(running)), "threshold": threshold,
                 "minutes": (time.time() - started) / 60, **scores[threshold]}
        history.append(entry)
        print(json.dumps(entry), flush=True)
        quality = entry["f1"] - .02 * entry["count_mae"]
        if quality > best:
            best = quality
            torch.save(model.state_dict(), args.output / "detect.pt")
            (args.output / "config.json").write_text(json.dumps(
                {"threshold": threshold, "architecture": "maskrcnn_resnet50_fpn_v2",
                 "detections": 300, "epoch": epoch + 1}, indent=2))
        (args.output / "training.json").write_text(json.dumps(history, indent=2))
    model.load_state_dict(torch.load(args.output / "detect.pt", map_location=device, weights_only=True))
    config = json.loads((args.output / "config.json").read_text())
    metrics = {"validation": evaluate(model, val, device)[config["threshold"]],
               "test": evaluate(model, test, device)[config["threshold"]],
               "threshold": config["threshold"]}
    (args.output / "metrics.json").write_text(json.dumps(metrics, indent=2))
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
