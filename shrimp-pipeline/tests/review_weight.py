"""Render held-group measured and predicted weights for review."""
import csv
import io
import json
import subprocess
from pathlib import Path
from zipfile import ZipFile

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
run = ROOT / "artifacts/weight-v1"
rows = json.loads((run / "metrics.json").read_text())["predictions"]
frames = []
for r in rows:
    if r["predicted_g"] is not None:
        frames.append(r)
frames.sort(key=lambda r: abs(r["predicted_g"] - r["actual_g"]))
source = ZipFile(ROOT / "data/raw/vannamei-anatomical-v1.zip")
prefix = "P3_DATASET_RELEASE/"
photos = {
    (row["base"], int(row["muestra_mendeley"])): prefix + row["base"] + "/" + row["archivo"]
    for row in csv.DictReader(io.StringIO(source.read(prefix + "labels.csv").decode()))
}
frames = [row for row in frames if (row["group"], row["specimen"]) in photos]
cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
       "-s", "880x460", "-r", "1/3", "-i", "-", "-c:v", "libx264", "-threads", "2",
       "-vf", "fps=24,format=yuv420p", "-movflags", "+faststart", str(run / "weight-review.mp4")]
with subprocess.Popen(cmd, stdin=subprocess.PIPE) as process:
    for row in [*frames[:2], *frames[len(frames)//2:len(frames)//2+2], *frames[-3:]]:
        canvas = Image.new("RGB", (880, 460), "#102322")
        draw = ImageDraw.Draw(canvas)
        draw.text((32, 22), "ShrimpMetric | Vannamei length-to-weight", fill="white", font_size=28)
        draw.text((32, 85), f"Held-out group {row['group']} | Manual length: {row['cm']:.2f} cm",
                  fill="#aaf5d1", font_size=22)
        photo = Image.open(io.BytesIO(source.read(photos[(row["group"], row["specimen"])]))).convert("RGB")
        photo.thumbnail((410, 280))
        canvas.paste(photo, (440, 115))
        for y, label, grams, color in (
            (166, "Scale", row["actual_g"], "#aaf5d1"),
            (274, "Model", row["predicted_g"], "#48b8e6"),
        ):
            draw.text((32, y), f"{label}: {grams:.2f} g", fill="white", font_size=22)
            draw.rounded_rectangle((32, y + 34, 32 + min(360, grams * 9), y + 66), 10, fill=color)
        draw.text((32, 411), "Source: Mendeley Vannamei Biomass v2 / Anatomical v1 | CC BY 4.0", fill="white", font_size=17)
        process.stdin.write(canvas.tobytes())
    process.stdin.close()
    if process.wait():
        raise RuntimeError("ffmpeg failed")

source.close()
