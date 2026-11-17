import 'dart:typed_data';

import '../domain/captured_frame.dart';
import 'shrimp_lite.dart';

/// A camera frame turned into the image the model works on.
class CalibratedFrame {
  const CalibratedFrame(this.image, this.pxPerCm);

  /// Canonical tray image, landscape 4:3: 2048 x 1536 when the camera gives
  /// enough pixels, otherwise 1024 x 768.
  final RgbImage image;

  /// Pixels of [image] per centimetre on the tray floor.
  final double pxPerCm;
}

/// Step between the camera and the model: rectify the tray and give the scale.
abstract class TrayCalibration {
  /// Stored with every record so results can be traced to how they were scaled.
  String get id;

  CalibratedFrame apply(CapturedFrame frame);
}

/// Placeholder until marker calibration exists.
///
/// It does not look at the markers. It takes the centre 4:3 part of the frame
/// and assumes the tray floor of the ShrimpMetric box fills the image width.
/// The floor length comes from the box drawing
/// (`12.box-shrimp-metric-3d/build.py`: `LB - 2 * T` = 386 mm).
///
/// The marker version replaces [apply]: find the four corner markers, warp the
/// floor to the canonical image and return the measured scale. The markers sit
/// on the sloped corner faces above the water line, so that version also has to
/// correct for the floor being lower than the marker plane and for refraction
/// in 50-60 mm of water.
class NominalBoxCalibration implements TrayCalibration {
  const NominalBoxCalibration();

  static const floorLengthCm = 38.6;

  @override
  String get id => 'nominal';

  @override
  CalibratedFrame apply(CapturedFrame frame) {
    // The tray is landscape. A portrait buffer is read with x and y swapped.
    final swap = frame.height > frame.width;
    final sw = swap ? frame.height : frame.width;
    final sh = swap ? frame.width : frame.height;
    var cropW = sw, cropH = sw * 3 ~/ 4;
    if (cropH > sh) {
      cropH = sh;
      cropW = sh * 4 ~/ 3;
    }
    final width = cropW >= 2048 ? 2048 : 1024;
    final height = width * 3 ~/ 4;
    final image = RgbImage(width, height);
    final x0 = (sw - cropW) / 2, y0 = (sh - cropH) / 2;
    final scaleX = cropW / width, scaleY = cropH / height;
    final out = image.bytes;
    final exact = cropW == width && cropH == height;
    final first = frame.planes.first;
    final sampler = switch (frame.format) {
      FrameFormat.yuv420 => _yuv(frame),
      FrameFormat.bgra8888 => _packed(first, 2, 1, 0),
      FrameFormat.rgb888 => _packed(first, 0, 1, 2),
    };
    final px = Uint8List(3);
    var o = 0;
    for (var y = 0; y < height; y++) {
      final fy = exact ? y0 + y : y0 + (y + .5) * scaleY - .5;
      for (var x = 0; x < width; x++) {
        final fx = exact ? x0 + x : x0 + (x + .5) * scaleX - .5;
        final u = (swap ? fy : fx).clamp(0.0, frame.width - 1.0);
        final v = (swap ? fx : fy).clamp(0.0, frame.height - 1.0);
        sampler(u, v, px);
        out[o++] = px[0];
        out[o++] = px[1];
        out[o++] = px[2];
      }
    }
    return CalibratedFrame(image, width / floorLengthCm);
  }
}

typedef _Sampler = void Function(double u, double v, Uint8List rgb);

/// Bilinear sample of a packed 8-bit format with the given channel offsets.
_Sampler _packed(FramePlane plane, int r, int g, int b) {
  final bytes = plane.bytes;
  final stride = plane.rowStride, step = plane.pixelStride;
  final offsets = [r, g, b];
  return (u, v, rgb) {
    final x = u.floor(), y = v.floor();
    final ax = u - x, ay = v - y;
    final p00 = y * stride + x * step;
    final p01 = ax > 0 ? p00 + step : p00;
    final p10 = ay > 0 ? p00 + stride : p00;
    final p11 = p10 + (p01 - p00);
    for (var c = 0; c < 3; c++) {
      final k = offsets[c];
      final top = bytes[p00 + k] + (bytes[p01 + k] - bytes[p00 + k]) * ax;
      final bottom = bytes[p10 + k] + (bytes[p11 + k] - bytes[p10 + k]) * ax;
      rgb[c] = (top + (bottom - top) * ay).round();
    }
  };
}

/// Bilinear luma, nearest chroma, BT.601 full range as in `prepareSample`.
_Sampler _yuv(CapturedFrame frame) {
  final luma = frame.planes[0], cb = frame.planes[1], cr = frame.planes[2];
  return (u, v, rgb) {
    final x = u.floor(), y = v.floor();
    final ax = u - x, ay = v - y;
    final p00 = y * luma.rowStride + x * luma.pixelStride;
    final p01 = ax > 0 ? p00 + luma.pixelStride : p00;
    final p10 = ay > 0 ? p00 + luma.rowStride : p00;
    final p11 = p10 + (p01 - p00);
    final top = luma.bytes[p00] + (luma.bytes[p01] - luma.bytes[p00]) * ax;
    final bottom = luma.bytes[p10] + (luma.bytes[p11] - luma.bytes[p10]) * ax;
    final l = top + (bottom - top) * ay;
    final cx = x ~/ 2, cy = y ~/ 2;
    final cu = cb.bytes[cy * cb.rowStride + cx * cb.pixelStride] - 128;
    final cv = cr.bytes[cy * cr.rowStride + cx * cr.pixelStride] - 128;
    rgb[0] = (l + 1.402 * cv).round().clamp(0, 255);
    rgb[1] = (l - .344136 * cu - .714136 * cv).round().clamp(0, 255);
    rgb[2] = (l + 1.772 * cu).round().clamp(0, 255);
  };
}
