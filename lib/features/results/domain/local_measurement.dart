class LocalMeasurement {
  const LocalMeasurement({
    required this.id,
    required this.sampleNumber,
    required this.measuredAt,
    required this.count,
    required this.frameCount,
    required this.imagePath,
  });

  final String id;
  final int sampleNumber;
  final DateTime measuredAt;
  final int count;
  final int frameCount;
  final String imagePath;
}
