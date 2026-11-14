"""Fit the vannamei length-to-weight baseline with pond-group validation."""
import argparse
import io
import json
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[2]


def samples():
    rows = []
    with ZipFile(ROOT / "data/raw/vannamei-biomass-v2.zip") as source:
        for name in source.namelist():
            if not name.endswith(".xlsx"):
                continue
            sheet = load_workbook(io.BytesIO(source.read(name)), read_only=True, data_only=True).active
            values = iter(sheet.values)
            header = next(values)
            for row in values:
                length, weight = (row[header.index(key)] for key in ("LENGTH (cm)", "WEIGHT (g)"))
                if isinstance(length, (float, int)) and isinstance(weight, (float, int)) and min(length, weight) > 0:
                    rows.append((Path(name).name[:3], length, weight, row[header.index("SAMPLE")]))
    return rows


def fit(rows):
    length, weight = np.asarray([(length, weight) for _, length, weight, _ in rows]).T
    b, log_a = np.polyfit(np.log(length), np.log(weight), 1)
    return {"a": float(np.exp(log_a)), "b": float(b), "min_cm": float(length.min()),
            "max_cm": float(length.max())}


def predict(model, cm):
    if not model["min_cm"] <= cm <= model["max_cm"]:
        return None
    return model["a"] * cm ** model["b"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/weight-v1")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    rows = samples()
    predictions = []
    for group in sorted({row[0] for row in rows}):
        model = fit([row for row in rows if row[0] != group])
        predictions.extend({"group": group, "specimen": specimen, "cm": cm, "actual_g": g, "predicted_g": predict(model, cm)}
                           for pond, cm, g, specimen in rows if pond == group)
    errors = np.asarray([p["predicted_g"] - p["actual_g"] for p in predictions if p["predicted_g"] is not None])
    report = {"samples": len(rows), "covered": len(errors), "mae_g": float(np.abs(errors).mean()),
              "bias_g": float(errors.mean()), "rmse_g": float(np.sqrt((errors ** 2).mean())),
              "validation": "leave-one-database-out", "predictions": predictions}
    model = dict(fit(rows), species="Penaeus vannamei", input="reference_length_cm",
                 output="estimated_weight_g", measurement_definition="Mendeley h8tcn6ykky.2 LENGTH (cm)")
    (args.output / "weight.json").write_text(json.dumps(model, indent=2) + "\n")
    (args.output / "metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    print({key: value for key, value in report.items() if key != "predictions"})


if __name__ == "__main__":
    main()
