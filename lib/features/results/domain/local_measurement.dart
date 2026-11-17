import '../../processing/domain/sample_analysis.dart';

class LocalMeasurement {
  const LocalMeasurement({
    required this.id,
    required this.sampleNumber,
    required this.measuredAt,
    required this.count,
    required this.frameCount,
    required this.imagePath,
    this.analysis,
  });

  final String id;
  final int sampleNumber;
  final DateTime measuredAt;
  final int count;
  final int frameCount;
  final String imagePath;

  /// Null for records saved before the on-device model.
  final SampleAnalysis? analysis;
}
