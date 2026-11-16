"""Export ShrimpLite as the one phone model file and verify that file, not the PyTorch model.

    python tests/export_lite.py [--model artifacts/lite-v2] [--output artifacts/phone-v1]

Writes `shrimp-lite.onnx` (float32, RGB 0..1, height and width free but multiples of 32) and
`config.json`. The same file serves Android and iOS through ONNX Runtime; the app feeds it
1 x 3 x 768 x 1024 for the first pass and 1 x 3 x 1536 x 2048 when the animals are small.
Then: output parity with PyTorch at both sizes, CPU latency by thread count and peak memory.
Accuracy of the file is measured with `tests/evaluate_detect.py --model artifacts/phone-v1`.
"""
import argparse
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import onnxruntime as ort
import torch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "pipeline"))
import run  # noqa: E402  (sets up model paths)
from run import lite  # noqa: E402

SIZES = {"pass1_768x1024": (768, 1024), "pass2_tile_864x1152": (864, 1152), "pass2_full_1536x2048": (1536, 2048)}
MEMORY = """
import sys, numpy as np, onnxruntime as ort
open("/proc/self/clear_refs", "w").write("5")  # the peak is inherited from the parent process; reset it
o = ort.SessionOptions(); o.intra_op_num_threads = 2; o.enable_cpu_mem_arena = False
s = ort.InferenceSession(sys.argv[1], o, providers=["CPUExecutionProvider"])
x = np.random.rand(1, 3, int(sys.argv[2]), int(sys.argv[3])).astype(np.float32)
for _ in range(3): s.run(None, {"rgb": x})
print([int(line.split()[1]) / 1024 for line in open("/proc/self/status") if line.startswith("VmHWM")][0])
"""


def latency(path, threads, height, width, runs=15):
    options = ort.SessionOptions()
    options.intra_op_num_threads = threads
    session = ort.InferenceSession(str(path), options, providers=["CPUExecutionProvider"])
    tensor = np.random.rand(1, 3, height, width).astype(np.float32)
    for _ in range(3):
        session.run(None, {"rgb": tensor})
    times = []
    for _ in range(runs):
        started = time.perf_counter()
        session.run(None, {"rgb": tensor})
        times.append((time.perf_counter() - started) * 1000)
    return {"median_ms": round(float(np.median(times)), 1), "p95_ms": round(float(np.percentile(times, 95)), 1)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=ROOT / "artifacts/lite-v2")
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/phone-v1")
    args = parser.parse_args()
    args.model, args.output = args.model.resolve(), args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    config = json.loads((args.model / "config.json").read_text())
    model = lite.ShrimpLite()
    model.load_state_dict(torch.load(args.model / "lite.pt", map_location="cpu", weights_only=True))
    model.eval()
    target = args.output / "shrimp-lite.onnx"
    torch.onnx.export(model, torch.rand(1, 3, 768, 1024), target, input_names=["rgb"], output_names=["maps"],
                      opset_version=17, dynamo=False,
                      dynamic_axes={"rgb": {2: "height", 3: "width"}, "maps": {2: "height_4", 3: "width_4"}})
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    (args.output / "config.json").write_text(json.dumps({
        "file": target.name, "sha256": digest, "trained_from": args.model.name, "epoch": config.get("epoch"),
        "threshold": config["threshold"], "kernel": config.get("kernel", 3), "stride": lite.STRIDE,
        "offset_scale": lite.OFFSET_SCALE, "body_threshold": .5, "min_cells": 3,
        "input": "rgb float32 [1, 3, H, W] in 0..1, H and W multiples of 32, pad value 0.45",
        "output": "maps float32 [1, 4, H/4, W/4]: centre logit, body logit, offset x, offset y (x 64 cells)",
        "canonical_image": [run.CANONICAL_SIDE, 1536], "first_pass_long_side": run.FIRST_PASS_SIDE,
        "second_pass_when_median_box_side_below_px": run.SMALL_ANIMAL}, indent=2))
    report = {"file": str(target.relative_to(ROOT)), "sha256": digest, "megabytes": round(target.stat().st_size / 1e6, 2),
              "host": "ONNX Runtime CPU on the development PC; no phone was measured", "sizes": {}}
    session = ort.InferenceSession(str(target), providers=["CPUExecutionProvider"])
    for name, (height, width) in SIZES.items():
        sample = torch.rand(1, 3, height, width)
        with torch.no_grad():
            reference = model(sample).numpy()
        difference = float(np.abs(session.run(None, {"rgb": sample.numpy()})[0] - reference).max())
        peak = float(subprocess.run([sys.executable, "-c", MEMORY, str(target), str(height), str(width)],
                                    capture_output=True, text=True, check=True).stdout.strip().splitlines()[-1])
        report["sizes"][name] = {"max_output_difference_vs_pytorch": round(difference, 5),
                                 "peak_process_memory_mb": round(peak),
                                 "latency_by_threads": {str(t): latency(target, t, height, width) for t in (1, 2, 4)}}
        print(name, json.dumps(report["sizes"][name]), flush=True)
    path = ROOT / "tests/reports" / f"{args.output.name}-export.json"
    path.write_text(json.dumps(report, indent=1))
    print("Saved:", path)


if __name__ == "__main__":
    main()
