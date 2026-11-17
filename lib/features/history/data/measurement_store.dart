import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../processing/domain/sample_analysis.dart';
import '../../results/domain/local_measurement.dart';

class MeasurementStore {
  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/measurements-v1').create(recursive: true);
  }

  Future<List<LocalMeasurement>> load() async {
    final root = await _root();
    final saved = <LocalMeasurement>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.reversed.skip(1).first;
      if (id.startsWith('.pending-') || id.startsWith('.deleted-')) {
        await entry.delete(recursive: true);
      } else {
        final metadata = jsonDecode(
          await File('${entry.path}/measurement.json').readAsString(),
        ) as Map<String, dynamic>;
        saved.add(
          LocalMeasurement(
            id: id,
            sampleNumber: metadata['sampleNumber'] as int? ?? 5,
            measuredAt: DateTime.parse(metadata['measuredAt'] as String)
                .toLocal(),
            count: metadata['count'] as int,
            frameCount: metadata['frameCount'] as int,
            imagePath: '${entry.path}/image.jpg',
            analysis: switch (metadata['analysis']) {
              final Map<String, dynamic> json => SampleAnalysis.fromJson(json),
              _ => null,
            },
          ),
        );
      }
    }
    saved.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return saved;
  }

  Future<LocalMeasurement> save({
    required List<int> jpeg,
    required int count,
    required int sampleNumber,
    required int frameCount,
    required DateTime measuredAt,
    SampleAnalysis? analysis,
  }) async {
    final root = await _root();
    final pending = await root.createTemp('.pending-');
    final id = pending.uri.pathSegments.reversed
        .skip(1)
        .first
        .replaceFirst('.pending-', '');
    try {
      await File('${pending.path}/image.jpg').writeAsBytes(jpeg, flush: true);
      await File('${pending.path}/measurement.json').writeAsString(
        jsonEncode({
          'measuredAt': measuredAt.toUtc().toIso8601String(),
          'count': count,
          'sampleNumber': sampleNumber,
          'frameCount': frameCount,
          'countSource': analysis == null ? 'simulation' : 'model',
          'analysis': ?analysis?.toJson(),
        }),
        flush: true,
      );
      final folder = await pending.rename('${root.path}/$id');
      return LocalMeasurement(
        id: id,
        sampleNumber: sampleNumber,
        measuredAt: measuredAt,
        count: count,
        frameCount: frameCount,
        imagePath: '${folder.path}/image.jpg',
        analysis: analysis,
      );
    } catch (_) {
      if (await pending.exists()) await pending.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final root = await _root();
    final folder = Directory('${root.path}/$id');
    final deleted = await folder.rename('${root.path}/.deleted-$id');
    try {
      await deleted.delete(recursive: true);
    } on FileSystemException {
      // The record is already hidden. Cleanup is retried at next load.
    }
  }
}
