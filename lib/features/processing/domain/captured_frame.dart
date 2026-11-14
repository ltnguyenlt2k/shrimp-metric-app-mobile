import 'dart:typed_data';

enum FrameFormat { yuv420, bgra8888 }

class FramePlane {
  const FramePlane(this.bytes, this.rowStride, this.pixelStride);

  final Uint8List bytes;
  final int rowStride;
  final int pixelStride;
}

class CapturedFrame {
  const CapturedFrame({
    required this.width,
    required this.height,
    required this.clockwiseRotation,
    required this.format,
    required this.planes,
  });

  final int width;
  final int height;
  final int clockwiseRotation;
  final FrameFormat format;
  final List<FramePlane> planes;
}
