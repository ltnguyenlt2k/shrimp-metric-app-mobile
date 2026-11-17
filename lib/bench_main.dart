import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'features/capture/data/simulated_camera.dart';
import 'features/processing/application/sample_analyzer.dart';

/// Development benchmark, not part of the app:
///
///     flutter run --release -t lib/bench_main.dart
///
/// Analyses every image in the simulated-camera folder as one capture of six
/// frames, twice, and writes the results and timings to `bench.json` in the
/// app's external files folder (also printed as `BENCH ...` lines).
void main() => runApp(const MaterialApp(home: _Bench()));

class _Bench extends StatefulWidget {
  const _Bench();

  @override
  State<_Bench> createState() => _BenchState();
}

class _BenchState extends State<_Bench> {
  var _status = 'Đang chuẩn bị…';

  @override
  void initState() {
    super.initState();
    _run().catchError((Object error, StackTrace stack) {
      // ignore: avoid_print
      print('BENCH_ERROR $error $stack');
      if (mounted) setState(() => _status = 'Lỗi: $error');
    });
  }

  Future<void> _run() async {
    final analyzer = SampleAnalyzer();
    final scenes = await SimulatedCamera.scenes();
    final records = <Map<String, dynamic>>[];
    for (var round = 0; round < 2; round++) {
      for (var k = 0; k < scenes.length; k++) {
        final name = scenes[k].uri.pathSegments.last;
        setState(() => _status = 'Lượt ${round + 1}/2 · ${k + 1}/${scenes.length}\n$name');
        final bytes = await scenes[k].readAsBytes();
        final frames = await simulateFramesOffThread(bytes, k);
        final sample = await analyzer.analyse(frames);
        final a = sample.analysis;
        final record = {
          'round': round,
          'scene': name,
          'model': a.modelVersion,
          'count': a.count,
          'countPerFrame': a.countPerFrame,
          'framesUsed': a.framesUsed,
          'lengthMm': a.lengthMm,
          'weightGrams': a.weightGrams,
          'gutIndex': a.gutIndex,
          'gut': [a.gutEmpty, a.gutPartial, a.gutFull, a.gutTotal - a.gutReadable],
          'timings': sample.timings,
          'rssMb': ProcessInfo.currentRss ~/ (1 << 20),
          'maxRssMb': ProcessInfo.maxRss ~/ (1 << 20),
        };
        records.add(record);
        // ignore: avoid_print
        print('BENCH ${jsonEncode(record)}');
      }
    }
    final folder = await getExternalStorageDirectory();
    await File('${folder!.path}/bench.json').writeAsString(jsonEncode(records));
    // ignore: avoid_print
    print('BENCH_DONE ${records.length}');
    if (mounted) setState(() => _status = 'Xong ${records.length} lượt đo.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_status, textAlign: TextAlign.center),
      ),
    ),
  );
}
