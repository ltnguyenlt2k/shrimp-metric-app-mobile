import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as image;

import '../domain/captured_frame.dart';

/// Presentation image for M2. Future analyzers consume the full frame batch
/// before it is released and can return independently computed metrics.
Future<Uint8List> prepareSample(List<CapturedFrame> frames) {
  return compute(_encodeRepresentative, frames[frames.length ~/ 2]);
}

Uint8List _encodeRepresentative(CapturedFrame frame) {
  final width = frame.width;
  final height = frame.height;
  final first = frame.planes.first;
  final image.Image rgb;
  if (frame.format == FrameFormat.bgra8888) {
    rgb = image.Image.fromBytes(
      width: width,
      height: height,
      bytes: first.bytes.buffer,
      bytesOffset: first.bytes.offsetInBytes,
      rowStride: first.rowStride,
      order: image.ChannelOrder.bgra,
    );
  } else {
    rgb = image.Image(width: width, height: height);
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];
    for (var y = 0; y < height; y++) {
      final lumaRow = y * first.rowStride;
      final uRow = (y ~/ 2) * uPlane.rowStride;
      final vRow = (y ~/ 2) * vPlane.rowStride;
      for (var x = 0; x < width; x++) {
        final chromaX = x ~/ 2;
        final luma = first.bytes[lumaRow + x * first.pixelStride];
        final u = uPlane.bytes[uRow + chromaX * uPlane.pixelStride] - 128;
        final v = vPlane.bytes[vRow + chromaX * vPlane.pixelStride] - 128;
        rgb.setPixelRgb(
          x,
          y,
          (luma + 1.402 * v).round().clamp(0, 255),
          (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
          (luma + 1.772 * u).round().clamp(0, 255),
        );
      }
    }
  }
  final oriented = frame.clockwiseRotation == 0
      ? rgb
      : image.copyRotate(rgb, angle: frame.clockwiseRotation);
  return image.encodeJpg(oriented, quality: 88);
}
