"""Benchmark actual exports and render a held-out review video."""
import argparse
import io
import json
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper
import onnxruntime as ort
from onnxruntime.quantization import CalibrationDataReader, QuantFormat, QuantType, quantize_static
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "models/count"))
from train import HEIGHT, STRIDE, WIDTH, load_rows, peaks, prepare


class Calibration(CalibrationDataReader):
    def __init__(self, rows):
        self.inputs = iter(rows)

    def get_next(self):
        return next(self.inputs, None)


def run(path, rows, threshold, render=False):
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = 2
    session = ort.InferenceSession(str(path), sess_options=opts, providers=["CPUExecutionProvider"])
    invoke = lambda x: session.run(["logits"], {"rgb": x[None]})[0]
    for _ in range(8):
        invoke(np.zeros((3, HEIGHT, WIDTH), np.float32))
    records = []
    for source, name, _, raw, boxes in rows:
        started = time.perf_counter()
        x, scale, (px, py) = prepare(raw)
        before_inference = time.perf_counter()
        logits = invoke(x)
        inferred = time.perf_counter()
        points = [(((cx + .5) * STRIDE - px) / scale, ((cy + .5) * STRIDE - py) / scale)
                  for _, _, cy, cx in peaks(logits, threshold)]
        completed = time.perf_counter()
        records.append({"source": source, "image": name, "label": len(boxes),
                        "predicted": len(points), "runtime_ms": 1000 * (inferred - before_inference),
                        "end_to_end_ms": 1000 * (completed - started),
                        **({"points": points} if render else {})})
    return records


def summarize(records):
    errors = np.array([r["predicted"] - r["label"] for r in records])
    return {"images": len(records), "mae": float(np.abs(errors).mean()), "bias": float(errors.mean()),
            "exact": float(np.mean(errors == 0)),
            "p50_runtime_ms": float(np.percentile([r["runtime_ms"] for r in records], 50)),
            "p95_runtime_ms": float(np.percentile([r["runtime_ms"] for r in records], 95)),
            "p95_end_to_end_ms": float(np.percentile([r["end_to_end_ms"] for r in records], 95))}


def video(rows, records, output):
    ranked = sorted(range(len(rows)), key=lambda i: abs(records[i]["predicted"] - records[i]["label"]))
    indexes = sorted(set([*ranked[:3], *ranked[-4:],
                         *[next(i for i, r in enumerate(records) if r["source"] == s)
                           for s in ("vannamei", "csiro")]]))
    external = next((i for i, row in enumerate(rows) if row[0] == "commons"), None)
    if external is not None:
        indexes.append(external)
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-threads", "2", "-f", "rawvideo", "-pix_fmt", "rgb24",
           "-s", "960x604", "-r", "1/3", "-i", "-", "-c:v", "libx264", "-threads", "2",
           "-vf", "fps=24,format=yuv420p", "-movflags", "+faststart", str(output)]
    with subprocess.Popen(cmd, stdin=subprocess.PIPE) as process:
        for i in indexes:
            raw = rows[i][3]
            record = records[i]
            frame = Image.new("RGB", (960, 604), "#102322")
            photo = Image.open(io.BytesIO(raw)).convert("RGB")
            width = photo.width
            photo.thumbnail((928, 520))
            ratio = photo.width / width
            left, top = (960 - photo.width) // 2, 56
            frame.paste(photo, (left, top))
            draw = ImageDraw.Draw(frame)
            draw.text((16, 10), "ShrimpMetric | Held-out images | ONNX FP16 weights", fill="white", font_size=20)
            draw.text((16, 34), f"{record['source']} | Labels: {record['label']} | Predicted: {record['predicted']}",
                      fill="#aaf5d1", font_size=16)
            for x, y in record["points"]:
                x, y = left + x * ratio, top + y * ratio
                draw.ellipse((x-5, y-5, x+5, y+5), outline="#5affae", width=3)
            attribution = ("Penaeus vannamei.jpg | Wikimedia Commons / iNaturalist (CC0)"
                           if record["source"] == "commons"
                           else "Sources: CSIRO / Mendeley anatomical subset (CC BY 4.0)")
            draw.text((16, 580), attribution, fill="white", font_size=14)
            process.stdin.write(frame.tobytes())
        process.stdin.close()
        if process.wait():
            raise RuntimeError("ffmpeg video encode failed")


def compress_weights(source, target):
    """Store Conv weights in FP16 and keep FP32 compute for CPU portability."""
    model = onnx.load(source)
    weights = {node.input[1] for node in model.graph.node if node.op_type == "Conv"}
    casts = []
    for value in model.graph.initializer:
        if value.name not in weights:
            continue
        name = value.name
        value.CopyFrom(numpy_helper.from_array(numpy_helper.to_array(value).astype(np.float16),
                                              name + "_fp16"))
        casts.append(helper.make_node("Cast", [value.name], [name], to=TensorProto.FLOAT))
    for cast in reversed(casts):
        model.graph.node.insert(0, cast)
    onnx.save(model, target)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", type=Path, default=ROOT / "artifacts/count-v1")
    args = parser.parse_args()
    run_dir = args.run
    fp32 = run_dir / "count.onnx"
    int8 = run_dir / "count-int8.onnx"
    fp16 = run_dir / "count-fp16-storage.onnx"
    compress_weights(fp32, fp16)
    threshold = json.loads((run_dir / "config.json").read_text())["threshold"]
    rows = load_rows()
    train = [row for row in rows if row[2] == "train"]
    test = [row for row in rows if row[2] == "test"]
    calibration = []
    for source in ("csiro", "vannamei"):
        pool = [r for r in train if r[0] == source]
        calibration.extend({"rgb": prepare(pool[i][3])[0][None]}
                           for i in np.linspace(0, len(pool) - 1, 32, dtype=int))
    quantize_static(str(fp32), str(int8), Calibration(calibration),
                    quant_format=QuantFormat.QDQ, activation_type=QuantType.QUInt8,
                    weight_type=QuantType.QInt8, op_types_to_quantize=["Conv"], per_channel=True)
    reports = {}
    for label, path in (("fp32", fp32), ("fp16_storage", fp16), ("int8", int8)):
        onnx.checker.check_model(str(path))
        predictions = run(path, test, threshold, render=label == "fp16_storage")
        reports[label] = {"bytes": path.stat().st_size, "grouped": {
            group: summarize([r for r in predictions if group == "all" or r["source"] == group])
            for group in ("all", "csiro", "vannamei")}}
        (run_dir / f"predictions-{label}.json").write_text(json.dumps(predictions, indent=2))
        if label == "fp16_storage":
            external_path = ROOT / "artifacts/external/vannamei-commons.jpg"
            external = [("commons", external_path.name, "external", external_path.read_bytes(), [[0, 0, 0, 0]])] if external_path.exists() else []
            outside = run(path, external, threshold, render=True)
            (run_dir / "external.json").write_text(json.dumps(outside, indent=2))
            video(test + external, predictions + outside, run_dir / "count-review.mp4")
    (run_dir / "metrics.json").write_text(json.dumps(reports, indent=2))
    print(json.dumps(reports, indent=2))


if __name__ == "__main__":
    main()
