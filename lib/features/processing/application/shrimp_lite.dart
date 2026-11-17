/// App-side half of the ShrimpLite model: tensors in, animals out.
///
/// This is a port of `shrimp-pipeline/models/lite/model.py:decode`,
/// `pipeline/run.py:PhoneDetector`, `pipeline/size.py` and `pipeline/gut.py`.
/// `test/shrimp_lite_test.dart` checks it against values produced by that
/// Python code, so change both sides together.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Packed RGB, three bytes per pixel.
class RgbImage {
  RgbImage(this.width, this.height, [Uint8List? bytes])
    : bytes = bytes ?? Uint8List(width * height * 3);

  final int width;
  final int height;
  final Uint8List bytes;
}

/// Everything that belongs to one exported model file. Read from the JSON
/// stored next to the model, so a new model only needs its two files replaced.
class LiteConfig {
  const LiteConfig({
    required this.version,
    required this.threshold,
    required this.kernel,
    required this.stride,
    required this.offsetScale,
    required this.minCells,
    required this.firstPassSide,
    required this.smallAnimalPx,
  });

  factory LiteConfig.fromJson(Map<String, dynamic> json) => LiteConfig(
    version: '${json['trained_from']}-${(json['sha256'] as String).substring(0, 8)}',
    threshold: (json['threshold'] as num).toDouble(),
    kernel: json['kernel'] as int,
    stride: json['stride'] as int,
    offsetScale: (json['offset_scale'] as num).toDouble(),
    minCells: json['min_cells'] as int,
    firstPassSide: json['first_pass_long_side'] as int,
    smallAnimalPx:
        (json['second_pass_when_median_box_side_below_px'] as num).toDouble(),
  );

  final String version;
  final double threshold;
  final int kernel;
  final int stride;
  final double offsetScale;
  final int minCells;
  final int firstPassSide;
  final double smallAnimalPx;
}

enum GutLevel { empty, partial, full, notObservable }

/// One animal in canonical-image pixels.
class ShrimpInstance {
  ShrimpInstance({
    required this.left,
    required this.top,
    required this.maskWidth,
    required this.maskHeight,
    required this.mask,
    required this.score,
  });

  int left;
  int top;
  final int maskWidth;
  final int maskHeight;
  final Uint8List mask;
  final double score;

  double lengthPx = 0;
  double widthPx = 0;
  bool touchesEdge = false;
  double? gutIndex;
  GutLevel gutLevel = GutLevel.notObservable;

  int get right => left + maskWidth;
  int get bottom => top + maskHeight;
  double get side => math.max(maskWidth, maskHeight).toDouble();
}

class ModelInput {
  ModelInput(this.tensor, this.height, this.width);

  final Float32List tensor;
  final int height;
  final int width;
}

const _pad = .45;

int _ceil32(int value) => (value + 31) ~/ 32 * 32;

/// Tensor for the first pass. A 2048 px canonical image is halved with the
/// same 4-tap filter PIL uses for a 2x bilinear reduction; a 1024 px image is
/// passed through.
ModelInput firstPassInput(RgbImage image, LiteConfig config) {
  if (image.width == config.firstPassSide) {
    return regionInput(image, 0, 0, image.width, image.height);
  }
  if (image.width != 2 * config.firstPassSide) {
    throw ArgumentError('Canonical width must be 1024 or 2048.');
  }
  final w = image.width ~/ 2, h = image.height ~/ 2;
  final tw = _ceil32(w), th = _ceil32(h);
  final tensor = Float32List(3 * th * tw)..fillRange(0, 3 * th * tw, _pad);
  final src = image.bytes;
  final sw = image.width, sh = image.height;
  // Horizontal pass into 16-bit sums (weights 1, 3, 3, 1).
  final rows = Uint16List(sh * w * 3);
  for (var y = 0; y < sh; y++) {
    final line = y * sw * 3;
    for (var x = 0; x < w; x++) {
      final x1 = 2 * x, x2 = x1 + 1;
      final x0 = x1 == 0 ? 0 : x1 - 1, x3 = x2 == sw - 1 ? x2 : x2 + 1;
      final out = (y * w + x) * 3;
      for (var c = 0; c < 3; c++) {
        rows[out + c] =
            src[line + x0 * 3 + c] +
            3 * (src[line + x1 * 3 + c] + src[line + x2 * 3 + c]) +
            src[line + x3 * 3 + c];
      }
    }
  }
  const norm = 1 / (64 * 255);
  for (var y = 0; y < h; y++) {
    final y1 = 2 * y, y2 = y1 + 1;
    final y0 = y1 == 0 ? 0 : y1 - 1, y3 = y2 == sh - 1 ? y2 : y2 + 1;
    final r0 = y0 * w * 3, r1 = y1 * w * 3, r2 = y2 * w * 3, r3 = y3 * w * 3;
    for (var x = 0; x < w; x++) {
      final k = x * 3;
      for (var c = 0; c < 3; c++) {
        tensor[c * th * tw + y * tw + x] =
            (rows[r0 + k + c] +
                3 * (rows[r1 + k + c] + rows[r2 + k + c]) +
                rows[r3 + k + c]) *
            norm;
      }
    }
  }
  return ModelInput(tensor, th, tw);
}

/// Tensor for a region of the canonical image at full resolution.
ModelInput regionInput(RgbImage image, int x0, int y0, int w, int h) {
  final tw = _ceil32(w), th = _ceil32(h);
  final plane = th * tw;
  final tensor = Float32List(3 * plane);
  if (tw != w || th != h) tensor.fillRange(0, 3 * plane, _pad);
  final src = image.bytes;
  const norm = 1 / 255;
  for (var y = 0; y < h; y++) {
    var s = ((y0 + y) * image.width + x0) * 3;
    var d = y * tw;
    for (var x = 0; x < w; x++, s += 3, d++) {
      tensor[d] = src[s] * norm;
      tensor[plane + d] = src[s + 1] * norm;
      tensor[2 * plane + d] = src[s + 2] * norm;
    }
  }
  return ModelInput(tensor, th, tw);
}

/// Groups one output `[4, h, w]` into animals. [cell] is the size of one output
/// cell in canonical pixels; [offsetX]/[offsetY] place a tile in the image.
List<ShrimpInstance> decodeMaps(
  Float32List maps,
  int h,
  int w,
  LiteConfig config, {
  required int cell,
  required int imageWidth,
  required int imageHeight,
  int offsetX = 0,
  int offsetY = 0,
}) {
  final n = h * w;
  final limit = math.log(config.threshold / (1 - config.threshold));
  final radius = config.kernel ~/ 2;
  // Separable sliding maximum of the centre logits.
  final rowMax = Float32List(n);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var best = maps[y * w + x];
      final from = math.max(0, x - radius), to = math.min(w - 1, x + radius);
      for (var k = from; k <= to; k++) {
        final v = maps[y * w + k];
        if (v > best) best = v;
      }
      rowMax[y * w + x] = best;
    }
  }
  final centreX = <int>[], centreY = <int>[];
  for (var y = 0; y < h; y++) {
    final from = math.max(0, y - radius), to = math.min(h - 1, y + radius);
    for (var x = 0; x < w; x++) {
      final v = maps[y * w + x];
      if (v < limit) continue;
      var best = v;
      for (var k = from; k <= to; k++) {
        final m = rowMax[k * w + x];
        if (m > best) best = m;
      }
      if (best == v) {
        centreX.add(x);
        centreY.add(y);
      }
    }
  }
  final count = centreX.length;
  if (count == 0) return [];
  final owner = Int32List(n)..fillRange(0, n, -1);
  final cells = Int32List(count);
  final minX = Int32List(count)..fillRange(0, count, w);
  final minY = Int32List(count)..fillRange(0, count, h);
  final maxX = Int32List(count)..fillRange(0, count, -1);
  final maxY = Int32List(count)..fillRange(0, count, -1);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (maps[n + i] < 0) continue; // body logit below 0.5 probability
      final tx = x + maps[2 * n + i] * config.offsetScale;
      final ty = y + maps[3 * n + i] * config.offsetScale;
      var best = 0;
      var bestDistance = double.infinity;
      for (var k = 0; k < count; k++) {
        final dx = tx - centreX[k], dy = ty - centreY[k];
        final distance = dx * dx + dy * dy;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = k;
        }
      }
      owner[i] = best;
      cells[best]++;
      if (x < minX[best]) minX[best] = x;
      if (x > maxX[best]) maxX[best] = x;
      if (y < minY[best]) minY[best] = y;
      if (y > maxY[best]) maxY[best] = y;
    }
  }
  final result = <ShrimpInstance>[];
  for (var k = 0; k < count; k++) {
    if (cells[k] < config.minCells) continue;
    final left = offsetX + minX[k] * cell, top = offsetY + minY[k] * cell;
    final mw = math.min((maxX[k] - minX[k] + 1) * cell, imageWidth - left);
    final mh = math.min((maxY[k] - minY[k] + 1) * cell, imageHeight - top);
    if (mw <= 0 || mh <= 0) continue;
    final mask = Uint8List(mw * mh);
    for (var y = 0; y < mh; y++) {
      final row = (minY[k] + y ~/ cell) * w + minX[k];
      for (var x = 0; x < mw; x++) {
        if (owner[row + x ~/ cell] == k) mask[y * mw + x] = 1;
      }
    }
    final logit = maps[centreY[k] * w + centreX[k]];
    result.add(
      ShrimpInstance(
        left: left,
        top: top,
        maskWidth: mw,
        maskHeight: mh,
        mask: mask,
        score: 1 / (1 + math.exp(-logit)),
      ),
    );
  }
  result.sort((a, b) => b.score.compareTo(a.score));
  return result;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Whether the animals of the first pass are small enough to need the image
/// at full resolution.
bool needsSecondPass(
  List<ShrimpInstance> found,
  RgbImage image,
  LiteConfig config,
) {
  if (found.isEmpty || image.width < 1.25 * config.firstPassSide) return false;
  final scale = config.firstPassSide / image.width;
  return _median([for (final item in found) item.side * scale]) <
      config.smallAnimalPx;
}

/// The four overlapping tiles of the second pass as (x, y, width, height).
List<(int, int, int, int)> secondPassTiles(RgbImage image) {
  final tw = _ceil32((image.width * .5625).round());
  final th = _ceil32((image.height * .5625).round());
  return [
    for (final y in [0, image.height - th])
      for (final x in [0, image.width - tw]) (x, y, tw, th),
  ];
}

/// Keeps the animals of a tile whose centre lies in that tile's own quarter.
List<ShrimpInstance> ownedByTile(
  List<ShrimpInstance> found,
  int tileX,
  int tileY,
  RgbImage image,
) => [
  for (final item in found)
    if (((item.left + item.right) / 2 < image.width / 2) == (tileX == 0) &&
        ((item.top + item.bottom) / 2 < image.height / 2) == (tileY == 0))
      item,
];

/// Drops the lower-scored of two boxes that overlap by more than half.
List<ShrimpInstance> suppressDuplicates(List<ShrimpInstance> found) {
  final sorted = [...found]..sort((a, b) => b.score.compareTo(a.score));
  final kept = <ShrimpInstance>[];
  for (final item in sorted) {
    final area = item.maskWidth * item.maskHeight;
    final duplicate = kept.any((other) {
      final w = math.min(item.right, other.right) - math.max(item.left, other.left);
      final h = math.min(item.bottom, other.bottom) - math.max(item.top, other.top);
      if (w <= 0 || h <= 0) return false;
      final overlap = w * h;
      return overlap / (area + other.maskWidth * other.maskHeight - overlap) > .5;
    });
    if (!duplicate) kept.add(item);
  }
  return kept;
}

class _Axes {
  _Axes(this.along, this.across, this.index);

  final Float64List along;
  final Float64List across;
  final List<int> index; // pixel index into the mask for every point
}

/// Mask points projected on the body's principal axis and its normal.
_Axes _project(ShrimpInstance item) {
  final w = item.maskWidth;
  final index = <int>[];
  var sumX = 0.0, sumY = 0.0;
  for (var i = 0; i < item.mask.length; i++) {
    if (item.mask[i] == 0) continue;
    index.add(i);
    sumX += i % w;
    sumY += i ~/ w;
  }
  final n = index.length;
  final meanX = sumX / n, meanY = sumY / n;
  var xx = 0.0, yy = 0.0, xy = 0.0;
  for (final i in index) {
    final dx = i % w - meanX, dy = i ~/ w - meanY;
    xx += dx * dx;
    yy += dy * dy;
    xy += dx * dy;
  }
  // Major axis of the 2x2 covariance.
  final angle = .5 * math.atan2(2 * xy, xx - yy);
  final ax = math.cos(angle), ay = math.sin(angle);
  final along = Float64List(n), across = Float64List(n);
  for (var k = 0; k < n; k++) {
    final dx = index[k] % w - meanX, dy = index[k] ~/ w - meanY;
    along[k] = dx * ax + dy * ay;
    across[k] = -dx * ay + dy * ax;
  }
  return _Axes(along, across, index);
}

/// Centre-line length and median body width in canonical pixels.
void measure(ShrimpInstance item, {int bins = 14}) {
  final axes = _project(item);
  final n = axes.along.length;
  if (n < 12) return;
  var low = double.infinity, high = -double.infinity;
  for (final v in axes.along) {
    if (v < low) low = v;
    if (v > high) high = v;
  }
  final step = (high + 1e-6 - low) / bins;
  final sumAlong = Float64List(bins), sumAcross = Float64List(bins);
  final members = Int32List(bins);
  final minAcross = Float64List(bins)..fillRange(0, bins, double.infinity);
  final maxAcross = Float64List(bins)..fillRange(0, bins, -double.infinity);
  for (var k = 0; k < n; k++) {
    final b = math.min(bins - 1, ((axes.along[k] - low) / step).floor());
    members[b]++;
    sumAlong[b] += axes.along[k];
    sumAcross[b] += axes.across[k];
    if (axes.across[k] < minAcross[b]) minAcross[b] = axes.across[k];
    if (axes.across[k] > maxAcross[b]) maxAcross[b] = axes.across[k];
  }
  final widths = <double>[];
  var path = 0.0;
  double? lastAlong, lastAcross;
  var centres = 0;
  for (var b = 0; b < bins; b++) {
    if (members[b] < 2) continue;
    final a = sumAlong[b] / members[b], c = sumAcross[b] / members[b];
    if (lastAlong != null) {
      path += math.sqrt(
        (a - lastAlong) * (a - lastAlong) + (c - lastAcross!) * (c - lastAcross),
      );
    }
    lastAlong = a;
    lastAcross = c;
    centres++;
    widths.add(maxAcross[b] - minAcross[b] + 1);
  }
  item.widthPx = widths.isEmpty ? 0 : _median(widths);
  // Slice centroids sit half a slice inside each end.
  item.lengthPx = centres < 2 ? high - low + 1 : path + step;
}

double _percentile25(List<double> values) {
  final sorted = [...values]..sort();
  final position = .25 * (sorted.length - 1);
  final lower = position.floor();
  final upper = math.min(lower + 1, sorted.length - 1);
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
}

/// Experimental gut-fullness index: the share of the abdomen's length with a
/// dark midline. Not validated; see `shrimp-pipeline/pipeline/gut.py`.
void gutFullness(RgbImage image, ShrimpInstance item) {
  const slices = 24, minWidth = 7, minBodyLuma = 70, minContrast = .16;
  final axes = _project(item);
  final n = axes.along.length;
  if (n < 60) return;
  var low = double.infinity, high = -double.infinity;
  for (final v in axes.along) {
    if (v < low) low = v;
    if (v > high) high = v;
  }
  final step = (high + 1e-3 - low) / slices;
  final parts = List.generate(slices, (_) => <int>[]);
  for (var k = 0; k < n; k++) {
    parts[math.min(slices - 1, ((axes.along[k] - low) / step).floor())].add(k);
  }
  final w = item.maskWidth;
  double luma(int k) {
    final i = axes.index[k];
    final p = ((item.top + i ~/ w) * image.width + item.left + i % w) * 3;
    return .299 * image.bytes[p] + .587 * image.bytes[p + 1] + .114 * image.bytes[p + 2];
  }

  var width = List<double>.filled(slices, 0);
  var contrast = List<double?>.filled(slices, null);
  var flankLuma = List<double?>.filled(slices, null);
  for (var s = 0; s < slices; s++) {
    final part = parts[s];
    if (part.length < 6) continue;
    final middle = _median([for (final k in part) axes.across[k]]);
    var lo = double.infinity, hi = -double.infinity;
    for (final k in part) {
      final offset = axes.across[k] - middle;
      if (offset < lo) lo = offset;
      if (offset > hi) hi = offset;
    }
    width[s] = hi - lo + 1;
    final centre = <double>[], flank = <double>[];
    for (final k in part) {
      final offset = (axes.across[k] - middle).abs();
      if (offset <= .22 * width[s]) centre.add(luma(k));
      if (offset >= .3 * width[s]) flank.add(luma(k));
    }
    if (centre.length >= 2 && flank.length >= 2) {
      final side = _median(flank);
      flankLuma[s] = side;
      contrast[s] = (side - _percentile25(centre)) / math.max(side, 1);
    }
  }
  // The cephalothorax is the wider end; the abdomen is 35-90% of the length from it.
  const third = slices ~/ 3;
  double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
  if (mean(width.take(third)) < mean(width.skip(slices - third))) {
    width = width.reversed.toList();
    contrast = contrast.reversed.toList();
    flankLuma = flankLuma.reversed.toList();
  }
  final from = (.35 * slices).floor(), to = (.9 * slices).floor();
  final usable = [for (var s = from; s < to; s++) if (contrast[s] != null) s];
  if (_median(width.sublist(from, to)) < minWidth || usable.length < 6) return;
  if (_median([for (final s in usable) flankLuma[s]!]) < minBodyLuma) return;
  final value =
      usable.where((s) => contrast[s]! >= minContrast).length / usable.length;
  item.gutIndex = (value * 100).round() / 100;
  item.gutLevel = value < .3
      ? GutLevel.empty
      : value < .7
      ? GutLevel.partial
      : GutLevel.full;
}

/// Length-to-weight rulers (`length-weight-tables.json`).
class WeightTables {
  WeightTables(Map<String, dynamic> json)
    : _tables = [
        for (final table in (json['tables'] as Map<String, dynamic>).values)
          [
            for (final point in (table as Map<String, dynamic>)['points_cm_g'] as List)
              (
                math.log((point as List)[0] as num),
                math.log(point[1] as num),
              ),
          ],
      ];

  final List<List<(double, double)>> _tables;

  (double, bool) _one(List<(double, double)> points, double cm) {
    final x = math.log(cm);
    final outside = x < points.first.$1 || x > points.last.$1;
    var k = points.indexWhere((p) => p.$1 >= x) - 1;
    if (k < -1) k = points.length - 2; // beyond the last mark
    k = k.clamp(0, points.length - 2);
    final slope =
        (points[k + 1].$2 - points[k].$2) / (points[k + 1].$1 - points[k].$1);
    return (math.exp(points[k].$2 + slope * (x - points[k].$1)), outside);
  }

  /// Grams for a total length: geometric mean of the rulers that cover it,
  /// or of their extrapolations when none does.
  double grams(double cm) {
    final values = [for (final table in _tables) _one(table, cm)];
    final covered = [for (final v in values) if (!v.$2) v.$1];
    final used = covered.isEmpty ? [for (final v in values) v.$1] : covered;
    return math.exp(
      used.map(math.log).reduce((a, b) => a + b) / used.length,
    );
  }
}

/// Measures every animal that is fully inside the frame.
void measureAll(RgbImage image, List<ShrimpInstance> found) {
  for (final item in found) {
    item.touchesEdge =
        item.left <= 2 ||
        item.top <= 2 ||
        item.right >= image.width - 2 ||
        item.bottom >= image.height - 2;
    measure(item);
    if (!item.touchesEdge) gutFullness(image, item);
  }
}

/// Sharpness, glare and darkness of a frame. The limits are heuristics from
/// the PC pipeline and still need tuning on field captures.
(bool, double) frameQuality(ModelInput input, int height, int width) {
  final plane = input.height * input.width;
  final gray = Float32List(height * width);
  var glare = 0, dark = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * input.width + x;
      final v =
          255 *
          (.299 * input.tensor[i] +
              .587 * input.tensor[plane + i] +
              .114 * input.tensor[2 * plane + i]);
      gray[y * width + x] = v;
      if (v >= 250) glare++;
      if (v <= 25) dark++;
    }
  }
  var sum = 0.0, squares = 0.0;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = y * width + x;
      final v = gray[i - 1] + gray[i + 1] + gray[i - width] + gray[i + width] - 4 * gray[i];
      sum += v;
      squares += v * v;
    }
  }
  final samples = (height - 2) * (width - 2);
  final sharpness = (squares - sum * sum / samples) / (samples - 1);
  final total = height * width;
  return (sharpness >= 25 && glare / total <= .25 && dark / total <= .6, sharpness);
}
