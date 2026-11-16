"""Experimental gut-fullness index from a top-view crop and its body mask.

Idea used in the literature and on farms: in a translucent shrimp seen from above, a filled
intestine is a dark line along the middle of the abdomen. The index is the share of the
abdomen's length where such a dark midline is present. Published image methods score the
digestive tract relative to the body (Connection Science 2023, doi 10.1080/09540091.2023.2268878)
or classify tray images (Aquaculture Reports 2025, doi 10.1016/j.aqrep.2025.103137).

Not validated: thresholds below are first guesses and there is no labelled data yet.
"""
import numpy as np

SLICES = 24
MIN_WIDTH_PX = 7        # narrower bodies cannot resolve a midline
MIN_BODY_LUMA = 70      # darker bodies (e.g. pigmented shrimp) hide the gut
CONTRAST = .16          # midline must be this much darker than the flanks
LEVELS = [(.3, "empty"), (.7, "partial"), (1.01, "full")]


def gut_fullness(rgb, mask):
    """rgb: uint8 [h, w, 3] crop; mask: bool [h, w]. Returns index 0..1, level and why not."""
    ys, xs = np.nonzero(mask)
    if len(xs) < 60:
        return {"index": None, "level": "not_observable", "reason": "too_small"}
    luma = rgb[ys, xs].astype(np.float32) @ np.array([.299, .587, .114], np.float32)
    points = np.stack([xs, ys], 1).astype(np.float32)
    points -= points.mean(0)
    vectors = np.linalg.eigh(np.cov(points.T))[1]
    along, across = points @ vectors[:, 1], points @ vectors[:, 0]
    edges = np.linspace(along.min(), along.max() + 1e-3, SLICES + 1)
    index = np.digitize(along, edges) - 1
    width, contrast, flank_luma = np.zeros(SLICES), np.full(SLICES, np.nan), np.full(SLICES, np.nan)
    for k in range(SLICES):
        part = index == k
        if part.sum() < 6:
            continue
        offset = across[part] - np.median(across[part])
        width[k] = offset.max() - offset.min() + 1
        centre = np.abs(offset) <= .22 * width[k]
        flank = np.abs(offset) >= .3 * width[k]
        if centre.sum() >= 2 and flank.sum() >= 2:
            flank_luma[k] = np.median(luma[part][flank])
            contrast[k] = (flank_luma[k] - np.percentile(luma[part][centre], 25)) / max(flank_luma[k], 1)
    # The cephalothorax is the wider end; the abdomen runs from 35% to 90% of the length from it.
    third = SLICES // 3
    if width[:third].mean() < width[-third:].mean():
        width, contrast, flank_luma = width[::-1], contrast[::-1], flank_luma[::-1]
    abdomen = slice(int(.35 * SLICES), int(.9 * SLICES))
    usable = ~np.isnan(contrast[abdomen])
    if np.median(width[abdomen]) < MIN_WIDTH_PX or usable.sum() < 6:
        return {"index": None, "level": "not_observable", "reason": "too_narrow"}
    if np.nanmedian(flank_luma[abdomen]) < MIN_BODY_LUMA:
        return {"index": None, "level": "not_observable", "reason": "body_too_dark"}
    value = float((contrast[abdomen][usable] >= CONTRAST).mean())
    level = next(name for limit, name in LEVELS if value < limit)
    return {"index": round(value, 2), "level": level, "reason": None}
