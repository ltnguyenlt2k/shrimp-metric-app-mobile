import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:shrimp_metric/features/processing/application/prepare_sample.dart';
import 'package:shrimp_metric/features/processing/domain/captured_frame.dart';

void main() {
  test(
    'Encodes the middle frame with rotation and strided YUV planes',
    () async {
      CapturedFrame frame(int luma) => CapturedFrame(
        width: 4,
        height: 2,
        clockwiseRotation: 90,
        format: FrameFormat.yuv420,
        planes: [
          FramePlane(
            Uint8List.fromList([
              luma,
              luma,
              luma,
              luma,
              0,
              0,
              luma,
              luma,
              luma,
              luma,
            ]),
            6,
            1,
          ),
          FramePlane(Uint8List.fromList([128, 0, 128]), 4, 2),
          FramePlane(Uint8List.fromList([128, 0, 128]), 4, 2),
        ],
      );

      final jpeg = await prepareSample([
        frame(20),
        frame(40),
        frame(180),
        frame(60),
        frame(80),
      ]);
      final decoded = image.decodeJpg(jpeg)!;
      expect(decoded.width, 2);
      expect(decoded.height, 4);
      expect(decoded.getPixel(0, 0).r, closeTo(180, 4));
    },
  );
}
