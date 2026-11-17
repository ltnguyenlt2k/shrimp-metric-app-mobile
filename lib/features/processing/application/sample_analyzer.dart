import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../domain/captured_frame.dart';
import '../domain/sample_analysis.dart';
import 'calibration.dart';
import 'shrimp_lite.dart';

/// Runs the bundled model on the frames of one capture.
///
/// To ship a new model, replace `assets/models/shrimp-lite.onnx` and
/// `shrimp-lite.json` (both written by `shrimp-pipeline/tests/export_lite.py`).
/// Nothing here changes as long as the input and output layout stay the same.
class SampleAnalyzer {
  SampleAnalyzer({this.calibration = const NominalBoxCalibration()});

  static const _folder = 'assets/models';

  final TrayCalibration calibration;
  OrtSession? _session;
  late LiteConfig _config;
  late WeightTables _tables;

  Future<void> load() async {
    if (_session != null) return;
    _config = LiteConfig.fromJson(
      jsonDecode(await rootBundle.loadString('$_folder/shrimp-lite.json'))
          as Map<String, dynamic>,
    );
    _tables = WeightTables(
      jsonDecode(await rootBundle.loadString('$_folder/length-weight-tables.json'))
          as Map<String, dynamic>,
    );
    _session = await OnnxRuntime().createSessionFromAsset(
      '$_folder/shrimp-lite.onnx',
      // Four threads suit phones with four fast cores; the arena is off to
      // keep peak memory low on small devices.
      options: OrtSessionOptions(intraOpNumThreads: 4, useArena: false),
    );
  }

  Future<void> close() async {
    await _session?.close();
    _session = null;
  }

  Future<Float32List> _run(ModelInput input) async {
    final tensor = await OrtValue.fromList(input.tensor, [
      1,
      3,
      input.height,
      input.width,
    ]);
    final outputs = await _session!.run({'rgb': tensor});
    final maps = outputs['maps']!;
    final data = await maps.asFlattenedList();
    await tensor.dispose();
    await maps.dispose();
    return data is Float32List ? data : Float32List.fromList(data.cast<double>());
  }

  Future<AnalysedSample> analyse(List<CapturedFrame> frames) async {
    final total = Stopwatch()..start();
    final loading = Stopwatch()..start();
    await load();
    loading.stop();
    final config = _config, calibration = this.calibration;
    final prepare = Stopwatch(), model = Stopwatch(), post = Stopwatch();
    final results = <_Frame>[];
    bool? secondPass;
    var modelRuns = 0;
    for (final frame in frames) {
      prepare.start();
      final ready = await _off(_prepare, (frame, calibration, config));
      prepare.stop();
      _Frame? result;
      if (secondPass != true) {
        model.start();
        final maps = await _run(ready.input);
        model.stop();
        modelRuns++;
        post.start();
        final decide = secondPass == null;
        result = await _off(_finishFirstPass, (ready, maps, config, decide));
        post.stop();
        secondPass ??= result == null;
      }
      if (result == null) {
        final tiles = secondPassTiles(ready.frame.image);
        final outputs = <Float32List>[];
        for (final tile in tiles) {
          prepare.start();
          final input = await _off(_tileInput, (ready.frame.image, tile));
          prepare.stop();
          model.start();
          outputs.add(await _run(input));
          model.stop();
          modelRuns++;
        }
        post.start();
        result = await _off(_finishSecondPass, (ready, outputs, config));
        post.stop();
      }
      results.add(result!);
    }
    final encode = Stopwatch()..start();
    final used = results.any((r) => r.usable)
        ? results.where((r) => r.usable).toList()
        : results;
    final mean = used.map((r) => r.count).reduce((a, b) => a + b) / used.length;
    final shown = used.reduce((a, b) {
      final da = (a.count - mean).abs(), db = (b.count - mean).abs();
      return db < da || (db == da && b.sharpness > a.sharpness) ? b : a;
    });
    final jpeg = await _off(_encode, shown.preview);
    encode.stop();

    final lengths = <double>[], weights = <double>[], guts = <double>[];
    for (final frame in used) {
      if (frame.lengthsPx.isNotEmpty) {
        final cm = [for (final px in frame.lengthsPx) px / frame.pxPerCm];
        lengths.add(cm.reduce((a, b) => a + b) / cm.length);
        weights.add(cm.map(_tables.grams).reduce((a, b) => a + b) / cm.length);
      }
      if (frame.gut.isNotEmpty) {
        guts.add(frame.gut.reduce((a, b) => a + b) / frame.gut.length);
      }
    }
    double? average(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    total.stop();
    return AnalysedSample(
      SampleAnalysis(
        modelVersion: config.version,
        calibration: calibration.id,
        count: mean.round(),
        countPerFrame: [for (final r in results) r.count],
        framesUsed: used.length,
        boxes: shown.boxes,
        lengthMm: switch (average(lengths)) {
          final cm? => cm * 10,
          _ => null,
        },
        weightGrams: average(weights),
        gutIndex: average(guts),
        gutReadable: shown.gut.length,
        gutTotal: shown.count,
        gutEmpty: shown.levels[GutLevel.empty.index],
        gutPartial: shown.levels[GutLevel.partial.index],
        gutFull: shown.levels[GutLevel.full.index],
      ),
      jpeg,
      {
        'frames': frames.length,
        'canonicalWidth': shown.canonicalWidth,
        'secondPass': secondPass == true ? 1 : 0,
        'modelRuns': modelRuns,
        'loadMs': loading.elapsedMilliseconds,
        'prepareMs': prepare.elapsedMilliseconds,
        'modelMs': model.elapsedMilliseconds,
        'postMs': post.elapsedMilliseconds,
        'encodeMs': encode.elapsedMilliseconds,
        'totalMs': total.elapsedMilliseconds,
      },
    );
  }
}

class _Ready {
  _Ready(this.frame, this.input, this.usable, this.sharpness, this.preview);

  final CalibratedFrame frame;
  final ModelInput input;
  final bool usable;
  final double sharpness;
  final RgbImage preview;
}

class _Frame {
  _Frame({
    required this.count,
    required this.boxes,
    required this.lengthsPx,
    required this.gut,
    required this.levels,
    required this.usable,
    required this.sharpness,
    required this.pxPerCm,
    required this.preview,
    required this.canonicalWidth,
  });

  final int count;
  final List<double> boxes;
  final List<double> lengthsPx;
  final List<double> gut;
  final List<int> levels;
  final bool usable;
  final double sharpness;
  final double pxPerCm;
  final RgbImage preview;
  final int canonicalWidth;
}

/// Runs [work] on another isolate. Only [work] and [argument] are sent there.
Future<R> _off<A, R>(R Function(A) work, A argument) =>
    Isolate.run(() => work(argument));

ModelInput _tileInput((RgbImage, (int, int, int, int)) args) {
  final (image, (x, y, w, h)) = args;
  return regionInput(image, x, y, w, h);
}

_Ready _prepare((CapturedFrame, TrayCalibration, LiteConfig) args) {
  final (frame, calibration, config) = args;
  final calibrated = calibration.apply(frame);
  final image = calibrated.image;
  final input = firstPassInput(image, config);
  final half = image.width == config.firstPassSide ? 1 : 2;
  final (usable, sharpness) = frameQuality(
    input,
    image.height ~/ half,
    image.width ~/ half,
  );
  return _Ready(
    calibrated,
    input,
    usable,
    sharpness,
    half == 1 ? image : _fromInput(input, image.width ~/ 2, image.height ~/ 2),
  );
}

/// The halved first-pass tensor back as 8-bit RGB, for the stored picture.
RgbImage _fromInput(ModelInput input, int width, int height) {
  final image = RgbImage(width, height);
  final plane = input.height * input.width;
  var o = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * input.width + x;
      for (var c = 0; c < 3; c++) {
        image.bytes[o++] = (input.tensor[c * plane + i] * 255).round();
      }
    }
  }
  return image;
}

/// Null when the animals are small and the frame needs the second pass.
_Frame? _finishFirstPass((_Ready, Float32List, LiteConfig, bool) args) {
  final (ready, maps, config, decide) = args;
  final image = ready.frame.image;
  final found = decodeMaps(
    maps,
    ready.input.height ~/ config.stride,
    ready.input.width ~/ config.stride,
    config,
    cell: config.stride * image.width ~/ config.firstPassSide,
    imageWidth: image.width,
    imageHeight: image.height,
  );
  if (decide && needsSecondPass(found, image, config)) return null;
  return _summarise(ready, found);
}

_Frame _finishSecondPass((_Ready, List<Float32List>, LiteConfig) args) {
  final (ready, outputs, config) = args;
  final image = ready.frame.image;
  final tiles = secondPassTiles(image);
  final found = <ShrimpInstance>[];
  for (var k = 0; k < tiles.length; k++) {
    final (x, y, w, h) = tiles[k];
    found.addAll(
      ownedByTile(
        decodeMaps(
          outputs[k],
          h ~/ config.stride,
          w ~/ config.stride,
          config,
          cell: config.stride,
          imageWidth: image.width,
          imageHeight: image.height,
          offsetX: x,
          offsetY: y,
        ),
        x,
        y,
        image,
      ),
    );
  }
  return _summarise(ready, suppressDuplicates(found));
}

_Frame _summarise(_Ready ready, List<ShrimpInstance> found) {
  final image = ready.frame.image;
  measureAll(image, found);
  final levels = List<int>.filled(GutLevel.values.length, 0);
  for (final item in found) {
    levels[item.gutLevel.index]++;
  }
  return _Frame(
    count: found.length,
    boxes: [
      for (final item in found) ...[
        item.left / image.width,
        item.top / image.height,
        item.right / image.width,
        item.bottom / image.height,
      ],
    ],
    lengthsPx: [
      for (final item in found)
        if (!item.touchesEdge && item.lengthPx > 0) item.lengthPx,
    ],
    gut: [
      for (final item in found)
        ?item.gutIndex,
    ],
    levels: levels,
    usable: ready.usable,
    sharpness: ready.sharpness,
    pxPerCm: ready.frame.pxPerCm,
    preview: ready.preview,
    canonicalWidth: image.width,
  );
}

Uint8List _encode(RgbImage picture) => img.encodeJpg(
  img.Image.fromBytes(
    width: picture.width,
    height: picture.height,
    bytes: picture.bytes.buffer,
    numChannels: 3,
  ),
  quality: 88,
);
