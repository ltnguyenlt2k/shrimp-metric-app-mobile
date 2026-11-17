import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shrimp_metric/features/capture/data/simulated_camera.dart';
import 'package:shrimp_metric/features/processing/application/calibration.dart';
import 'package:shrimp_metric/features/processing/application/shrimp_lite.dart';
import 'package:shrimp_metric/features/processing/domain/captured_frame.dart';
import 'package:image/image.dart' as img;

/// Fixtures come from `shrimp-pipeline/tests/app_fixtures.py`: the model output
/// for one image and what the Python reference code makes of it.
void main() {
  final folder = Directory('test/fixtures/lite');
  final expected =
      jsonDecode(File('${folder.path}/expected.json').readAsStringSync())
          as Map<String, dynamic>;
  final settings = expected['config'] as Map<String, dynamic>;
  LiteConfig config({int firstPassSide = 1024}) => LiteConfig(
    version: 'test',
    threshold: (settings['threshold'] as num).toDouble(),
    kernel: settings['kernel'] as int,
    stride: settings['stride'] as int,
    offsetScale: (settings['offset_scale'] as num).toDouble(),
    minCells: settings['min_cells'] as int,
    firstPassSide: firstPassSide,
    smallAnimalPx: 96,
  );

  test('Groups, measures and scores animals like the Python reference', () {
    final image = RgbImage(
      512,
      384,
      File('${folder.path}/image-512x384.rgb').readAsBytesSync(),
    );
    final maps = File(
      '${folder.path}/maps-4x96x128.f32',
    ).readAsBytesSync().buffer.asFloat32List();
    final found = decodeMaps(
      maps,
      96,
      128,
      config(),
      cell: 4,
      imageWidth: 512,
      imageHeight: 384,
    );
    measureAll(image, found);
    final animals = (expected['animals'] as List).cast<Map<String, dynamic>>();
    expect(found.length, animals.length);
    expect(animals.length, greaterThan(3));
    for (final reference in animals) {
      final box = (reference['box'] as List).cast<int>();
      final item = found.singleWhere(
        (item) => item.left == box[0] && item.top == box[1],
      );
      expect([item.right, item.bottom], [box[2], box[3]]);
      expect(item.score, closeTo(reference['score'] as num, 1e-4));
      expect(item.touchesEdge, reference['edge']);
      expect(item.lengthPx, closeTo(reference['length_px'] as num, .05));
      expect(item.widthPx, closeTo(reference['width_px'] as num, .05));
      expect(item.gutLevel.name, switch (reference['gut_level']) {
        'not_observable' => 'notObservable',
        final String level => level,
        _ => fail('level'),
      });
      if (reference['gut_index'] case final num index) {
        expect(item.gutIndex, closeTo(index, .011));
      } else {
        expect(item.gutIndex, isNull);
      }
    }
  });

  test('Converts length to weight like the ruler tables in Python', () {
    final tables = WeightTables(
      jsonDecode(
            File('assets/models/length-weight-tables.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    (expected['weights_g'] as Map<String, dynamic>).forEach((cm, grams) {
      expect(
        tables.grams(double.parse(cm)),
        closeTo(grams as num, 1e-4 * grams + 1e-5),
      );
    });
  });

  test('Halves the canonical image like the PC resize', () {
    final input = RgbImage(
      64,
      48,
      File('${folder.path}/half-in-64x48.rgb').readAsBytesSync(),
    );
    final tensor = firstPassInput(input, config(firstPassSide: 32));
    final reference = (expected['half_out_32x24'] as List).cast<int>();
    expect((tensor.height, tensor.width), (32, 32)); // 24 rows padded to 32
    // PIL rounds to 8 bits between its two passes, so values differ by up to 1.
    // Image borders differ: PIL renormalises there, the app repeats the edge.
    for (var y = 1; y < 23; y++) {
      for (var x = 1; x < 31; x++) {
        for (var c = 0; c < 3; c++) {
          expect(
            tensor.tensor[c * 32 * 32 + y * 32 + x] * 255,
            closeTo(reference[(y * 32 + x) * 3 + c], 1.01),
          );
        }
      }
    }
  });

  test('Placeholder calibration passes a canonical RGB frame through', () {
    final bytes = Uint8List(1024 * 768 * 3);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = i * 7 % 251;
    }
    final result = const NominalBoxCalibration().apply(
      CapturedFrame(
        width: 1024,
        height: 768,
        clockwiseRotation: 0,
        format: FrameFormat.rgb888,
        planes: [FramePlane(bytes, 1024 * 3, 3)],
      ),
    );
    expect((result.image.width, result.image.height), (1024, 768));
    expect(result.image.bytes, bytes);
    expect(result.pxPerCm, closeTo(1024 / 38.6, 1e-9));
  });

  test('Placeholder calibration crops a 16:9 YUV frame to 4:3', () {
    Uint8List plane(int length, int value) =>
        Uint8List(length)..fillRange(0, length, value);
    final result = const NominalBoxCalibration().apply(
      CapturedFrame(
        width: 1280,
        height: 720,
        clockwiseRotation: 90,
        format: FrameFormat.yuv420,
        planes: [
          FramePlane(plane(1280 * 720, 120), 1280, 1),
          FramePlane(plane(640 * 360, 128), 640, 1),
          FramePlane(plane(640 * 360, 128), 640, 1),
        ],
      ),
    );
    expect((result.image.width, result.image.height), (1024, 768));
    expect(result.image.bytes.every((value) => value == 120), isTrue);
  });

  test('Simulated camera yields six frames from one photograph', () {
    final picture = img.Image(width: 64, height: 48)
      ..clear(img.ColorRgb8(90, 140, 200));
    final frames = simulateFrames(img.encodeJpg(picture, quality: 95), 3);
    expect(frames.length, 6);
    expect(frames.every((f) => f.width == 64 && f.height == 48), isTrue);
    expect(frames.first.planes.single.bytes.length, 64 * 48 * 3);
    expect(frames[1].planes.single.bytes[0], closeTo(90, 6));
  });
}
