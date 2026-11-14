"""Run the existing export on published photographs of shrimp in trays."""
import io
import json

from PIL import Image

from review_count import ROOT, run, video

# Bounds on a 750x507 reference view of the published figure.
PANELS = {
    "pl-tiger-a": (2, 2, 175, 233),
    "pl-tiger-b": (192, 2, 366, 233),
    "pl-tiger-c": (382, 2, 556, 233),
    "pl-tiger-d": (573, 2, 746, 233),
    "pl-tiger-e": (2, 254, 175, 485),
    "pl-tiger-f": (192, 254, 366, 485),
    "pl-tiger-g": (391, 254, 563, 485),
}


def main():
    output = ROOT / "artifacts/count-v1"
    source = Image.open(ROOT / "artifacts/external/li2023-figure2.png")
    rows = []
    for name, bounds in PANELS.items():
        scale = (source.width / 750, source.height / 507)
        panel = source.crop(tuple(round(v * scale[i % 2]) for i, v in enumerate(bounds)))
        buffer = io.BytesIO()
        panel.save(buffer, format="PNG")
        rows.append(("li2023", name, "external", buffer.getvalue(), None))
    for name in ("thenho-tray-a", "thenho-tray-b"):
        photo = ROOT / "artifacts/external" / f"{name}.jpg"
        rows.append(("thenho", name, "external", photo.read_bytes(), None))
    threshold = json.loads((output / "config.json").read_text())["threshold"]
    results = run(output / "count-fp16-storage.onnx", rows, threshold, render=True)
    (output / "tray-predictions.json").write_text(json.dumps(results, indent=2) + "\n")
    video(rows, results, output / "count-tray-review.mp4", tray_only=True)


if __name__ == "__main__":
    main()
