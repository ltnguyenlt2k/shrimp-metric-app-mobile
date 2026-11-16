"""Body measurements from masks and length -> weight -> count-per-kg conversion."""
import json
import math
from pathlib import Path

import numpy as np

TABLES = json.loads((Path(__file__).with_name("length_weight_tables.json")).read_text(encoding="utf-8"))


def measure(mask, bins=14):
    """Centre-line length and body width of one mask, in mask pixels.

    The mask is sliced along its principal axis; the length follows the slice centroids so a
    curved animal is not shortened to its chord. Width is the median slice thickness.
    """
    ys, xs = np.nonzero(mask)
    if len(xs) < 12:
        return 0.0, 0.0
    points = np.stack([xs, ys], 1).astype(np.float64)
    points -= points.mean(0)
    vectors = np.linalg.eigh(np.cov(points.T))[1]
    along, across = points @ vectors[:, 1], points @ vectors[:, 0]
    edges = np.linspace(along.min(), along.max() + 1e-6, bins + 1)
    index = np.digitize(along, edges) - 1
    centres, widths = [], []
    for k in range(bins):
        part = index == k
        if part.sum() >= 2:
            centres.append((along[part].mean(), across[part].mean()))
            widths.append(across[part].max() - across[part].min() + 1)
    if len(centres) < 2:
        return float(along.max() - along.min() + 1), float(np.median(widths)) if widths else 0.0
    centres = np.array(centres)
    path = np.linalg.norm(np.diff(centres, axis=0), axis=1).sum()
    # Slice centroids sit half a slice inside each end.
    return float(path + (edges[1] - edges[0])), float(np.median(widths))


def _table_weight(cm, name):
    points = TABLES["tables"][name]["points_cm_g"]
    lengths = [math.log(p[0]) for p in points]
    weights = [math.log(p[1]) for p in points]
    x = math.log(cm)
    outside = not lengths[0] <= x <= lengths[-1]
    k = min(max(int(np.searchsorted(lengths, x)) - 1, 0), len(points) - 2)
    slope = (weights[k + 1] - weights[k]) / (lengths[k + 1] - lengths[k])
    return math.exp(weights[k] + slope * (x - lengths[k])), outside


def weight_from_length(cm, table=None):
    """Grams for a total length in cm. Returns (grams, extrapolated).

    One ruler: log-log interpolation inside its table, the nearest segment's power law outside.
    "average": geometric mean of the rulers that cover the length; when none covers it, the
    geometric mean of their extrapolations.
    """
    table = table or TABLES["default"]
    if table != "average":
        return _table_weight(cm, table)
    values = [_table_weight(cm, name) for name in TABLES["tables"]]
    covered = [grams for grams, outside in values if not outside]
    used = covered or [grams for grams, _ in values]
    return math.exp(sum(math.log(g) for g in used) / len(used)), not covered


def summarise(lengths_cm, table=None):
    """Tray summary from per-animal total lengths."""
    if not lengths_cm:
        return None
    grams = [weight_from_length(cm, table) for cm in lengths_cm]
    weights = np.array([g for g, _ in grams])
    lengths = np.array(lengths_cm)
    return {"table": table or TABLES["default"], "animals_measured": len(lengths),
            "length_cm_mean": round(float(lengths.mean()), 2),
            "length_cm_cv_percent": round(float(lengths.std() / lengths.mean() * 100), 1),
            "weight_g_mean": round(float(weights.mean()), 3),
            "count_per_kg": round(1000 * len(weights) / float(weights.sum())),
            "extrapolated_animals": int(sum(flag for _, flag in grams))}
