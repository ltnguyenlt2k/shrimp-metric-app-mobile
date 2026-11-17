import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../processing/domain/captured_frame.dart';
import 'camera_session.dart';

/// Development camera: feeds photographs from the device instead of the lens,
/// so the whole capture and analysis path can be checked on an emulator.
///
/// Enabled with `--dart-define=SIM_CAMERA=true`. Images are read from
/// `<app external files>/sim-camera/*.jpg` in name order, one per capture,
/// and must already be landscape 4:3 as the calibrated tray image will be.
/// Each capture yields six frames with a small shift and brightness change,
/// standing in for hand movement. Release builds for users leave this off.
class SimulatedCamera implements FrameSource {
  static var _next = 0;

  File? _file;

  static Future<List<File>> scenes() async {
    final root = await getExternalStorageDirectory();
    final folder = Directory('${root?.path}/sim-camera');
    if (root == null) return const [];
    // Created by the app so that it owns the folder; files are pushed with adb.
    await folder.create(recursive: true);
    final files = [
      await for (final entry in folder.list())
        if (entry is File && entry.path.toLowerCase().endsWith('.jpg')) entry,
    ];
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  @override
  bool get ready => _file != null;

  @override
  Widget preview() => Image.file(_file!, fit: BoxFit.contain);

  @override
  Future<void> open() async {
    final files = await scenes();
    if (files.isEmpty) throw const CameraUnavailable();
    _file = files[_next % files.length];
  }

  @override
  Future<List<CapturedFrame>> capture() async {
    final bytes = await _file!.readAsBytes();
    final seed = _next++;
    return simulateFramesOffThread(bytes, seed);
  }

  @override
  void interrupt() {}

  @override
  Future<void> close() async => _file = null;
}

/// [simulateFrames] on another isolate. Kept at top level so that only the
/// two arguments are sent there.
Future<List<CapturedFrame>> simulateFramesOffThread(Uint8List jpeg, int seed) =>
    Isolate.run(() => simulateFrames(jpeg, seed));

List<CapturedFrame> simulateFrames(Uint8List jpeg, int seed, {int count = 6}) {
  final decoded = img.decodeJpg(jpeg)!;
  final width = decoded.width, height = decoded.height;
  final source = decoded.getBytes(order: img.ChannelOrder.rgb);
  final random = Random(seed);
  return [
    for (var k = 0; k < count; k++)
      CapturedFrame(
        width: width,
        height: height,
        clockwiseRotation: 0,
        format: FrameFormat.rgb888,
        planes: [
          FramePlane(
            k == 0
                ? source
                : _shifted(
                    source,
                    width,
                    height,
                    random.nextInt(9) - 4,
                    random.nextInt(9) - 4,
                    .97 + random.nextDouble() * .06,
                  ),
            width * 3,
            3,
          ),
        ],
      ),
  ];
}

Uint8List _shifted(Uint8List source, int width, int height, int dx, int dy, double gain) {
  final gains = Uint8List.fromList([
    for (var v = 0; v < 256; v++) (v * gain).round().clamp(0, 255),
  ]);
  final out = Uint8List(source.length);
  var o = 0;
  for (var y = 0; y < height; y++) {
    final row = (y + dy).clamp(0, height - 1) * width;
    for (var x = 0; x < width; x++) {
      final p = (row + (x + dx).clamp(0, width - 1)) * 3;
      out[o++] = gains[source[p]];
      out[o++] = gains[source[p + 1]];
      out[o++] = gains[source[p + 2]];
    }
  }
  return out;
}
