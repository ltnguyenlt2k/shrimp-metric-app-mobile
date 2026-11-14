class SampleMeasurement {
  const SampleMeasurement({
    required this.id,
    required this.count,
    required this.measuredAt,
    this.averageWeightGrams = 0.456,
    this.averageLengthMm = 34.2,
    this.hasPreview = false,
    this.imagePath,
    this.storageId,
  });

  final int id;
  final int count;
  final DateTime measuredAt;
  final bool hasPreview;
  final String? imagePath;
  final String? storageId;
  final double averageWeightGrams;
  final double averageLengthMm;

  double get shrimpPerKg => 1000 / averageWeightGrams;

  String get dateLabel =>
      '${measuredAt.day}/${measuredAt.month}/${measuredAt.year}';

  String get timeLabel =>
      '${measuredAt.hour.toString().padLeft(2, '0')}:${measuredAt.minute.toString().padLeft(2, '0')}';
}

enum SampleMetric {
  count('Số lượng', 'con', 0),
  size('Cỡ tôm', 'con/kg', 0),
  weight('Khối lượng TB', 'g/con', 3),
  length('Chiều dài TB', 'mm', 1);

  const SampleMetric(this.label, this.unit, this.decimals);

  final String label;
  final String unit;
  final int decimals;

  double value(SampleMeasurement sample) => switch (this) {
    count => sample.count.toDouble(),
    size => sample.shrimpPerKg,
    weight => sample.averageWeightGrams,
    length => sample.averageLengthMm,
  };

  String format(double value, {bool includeUnit = true}) {
    final parts = value.toStringAsFixed(decimals).split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final number = parts.length == 1 ? whole : '$whole,${parts.last}';
    return includeUnit ? '$number $unit' : number;
  }
}
