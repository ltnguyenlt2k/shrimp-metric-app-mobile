"""ShrimpLite: a fully convolutional instance model sized for phones.

One pass gives three stride-4 maps: animal-centre heatmap, body (foreground) mask and, for
every body pixel, the offset to its animal's centre. Instances are formed by sending each
body pixel to the nearest detected centre. There are no proposals, RoI layers or NMS graphs,
so the network converts to LiteRT/Core ML as plain convolutions and the grouping runs in
app code.
"""
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F
from torchvision.models import mobilenet_v3_large

ROOT = Path(__file__).resolve().parents[2]
PRETRAINED = ROOT / "checkpoints/pretrained/mobilenet-v3-large-imagenet1k-v2.pth"
STRIDE = 4
OFFSET_SCALE = 64.0  # offsets are predicted in units of 64 output cells


def separable(channels_in, channels_out):
    return nn.Sequential(nn.Conv2d(channels_in, channels_in, 3, padding=1, groups=channels_in, bias=False),
                         nn.Conv2d(channels_in, channels_out, 1, bias=False),
                         nn.BatchNorm2d(channels_out), nn.ReLU(inplace=True))


class ShrimpLite(nn.Module):
    def __init__(self, pretrained=False, width=96):
        super().__init__()
        base = mobilenet_v3_large()
        if pretrained:
            base.load_state_dict(torch.load(PRETRAINED, map_location="cpu", weights_only=True))
        features = base.features
        self.stages = nn.ModuleList([features[:4], features[4:7], features[7:13], features[13:16]])
        self.lateral = nn.ModuleList([nn.Conv2d(c, width, 1) for c in (24, 40, 112, 160)])
        self.smooth = nn.ModuleList([separable(width, width) for _ in range(3)])
        self.trunk = nn.Sequential(separable(width, width), separable(width, width))
        self.heat = nn.Conv2d(width, 1, 1)
        self.body = nn.Conv2d(width, 1, 1)
        self.offset = nn.Conv2d(width, 2, 1)
        nn.init.constant_(self.heat.bias, -4.0)
        self.register_buffer("mean", torch.tensor([.485, .456, .406]).view(1, 3, 1, 1))
        self.register_buffer("std", torch.tensor([.229, .224, .225]).view(1, 3, 1, 1))

    def forward(self, rgb):
        """rgb: [B, 3, H, W] in 0..1, H and W multiples of 32. Returns one [B, 4, H/4, W/4]
        tensor: centre logit, body logit, offset x, offset y (offsets in OFFSET_SCALE cells)."""
        x = (rgb - self.mean) / self.std
        levels = []
        for stage in self.stages:
            x = stage(x)
            levels.append(x)
        top = self.lateral[3](levels[3])
        for i in (2, 1, 0):
            top = self.smooth[i](self.lateral[i](levels[i]) + F.interpolate(top, scale_factor=2.0, mode="nearest"))
        top = self.trunk(top)
        return torch.cat([self.heat(top), self.body(top), self.offset(top)], 1)


def targets(masks, height, width):
    """Training maps at stride 4 from bool masks [N, H, W] (numpy). Returns heat, body, offset."""
    h, w = height // STRIDE, width // STRIDE
    heat = np.zeros((h, w), np.float32)
    body = np.zeros((h, w), np.float32)
    offset = np.zeros((2, h, w), np.float32)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    for mask in masks:
        small = mask[STRIDE // 2::STRIDE, STRIDE // 2::STRIDE][:h, :w]
        py, px = np.nonzero(small)
        if len(px) < 2:
            continue
        # Centre = body cell nearest the centroid, so it lies on the animal even when it is curved.
        k = np.argmin((px - px.mean()) ** 2 + (py - py.mean()) ** 2)
        cx, cy = float(px[k]), float(py[k])
        extent = max(px.max() - px.min(), py.max() - py.min()) + 1
        sigma = max(1.0, extent * .06)
        heat = np.maximum(heat, np.exp(-((xs - cx) ** 2 + (ys - cy) ** 2) / (2 * sigma ** 2)))
        heat[int(cy), int(cx)] = 1.0
        body[py, px] = 1.0
        offset[0, py, px] = (cx - px) / OFFSET_SCALE
        offset[1, py, px] = (cy - py) / OFFSET_SCALE
    return heat, body, offset


def loss_fn(output, heat, body, offset):
    logit = output[:, 0]
    prob = logit.sigmoid().clamp(1e-4, 1 - 1e-4)
    positive = heat == 1
    focal = torch.where(positive, -(1 - prob) ** 2 * prob.log(),
                        -(1 - heat) ** 4 * prob ** 2 * (1 - prob).log())
    heat_loss = focal.sum() / positive.sum().clamp(min=1)
    body_logit = output[:, 1]
    bce = F.binary_cross_entropy_with_logits(body_logit, body)
    body_prob = body_logit.sigmoid()
    dice = 1 - (2 * (body_prob * body).sum() + 1) / (body_prob.sum() + body.sum() + 1)
    weight = body[:, None]
    offset_loss = (F.smooth_l1_loss(output[:, 2:], offset, beta=.02, reduction="none") * weight).sum() \
        / weight.sum().clamp(min=1) / 2
    return heat_loss + bce + dice + 20 * offset_loss, (heat_loss.item(), (bce + dice).item(), offset_loss.item())


def decode(output, threshold=.3, body_threshold=.5, min_cells=3, kernel=3):
    """Group one image's output [4, h, w] (torch, cpu) into instances.

    Returns scores [N], and a list of (x0, y0, mask) in output cells. This is the reference for
    the app-side implementation: 3x3 peak picking, then nearest-centre assignment.
    """
    heat = output[0].sigmoid()
    peak = (heat == F.max_pool2d(heat[None, None], kernel, 1, kernel // 2)[0, 0]) & (heat >= threshold)
    centres = peak.nonzero()  # [K, 2] as (y, x)
    body = output[1].sigmoid() >= body_threshold
    if not len(centres) or not body.any():
        return torch.zeros(0), []
    py, px = body.nonzero(as_tuple=True)
    target = torch.stack([py + output[3, py, px] * OFFSET_SCALE, px + output[2, py, px] * OFFSET_SCALE], 1)
    owner = torch.cdist(target.float(), centres.float()).argmin(1)
    scores, items = [], []
    for k in range(len(centres)):
        mine = owner == k
        if int(mine.sum()) < min_cells:
            continue
        y, x = py[mine], px[mine]
        y0, x0 = int(y.min()), int(x.min())
        mask = np.zeros((int(y.max()) - y0 + 1, int(x.max()) - x0 + 1), bool)
        mask[(y - y0).numpy(), (x - x0).numpy()] = True
        scores.append(heat[centres[k, 0], centres[k, 1]])
        items.append((x0, y0, mask))
    return (torch.stack(scores) if scores else torch.zeros(0)), items
