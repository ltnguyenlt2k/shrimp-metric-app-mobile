import 'dart:typed_data';

/// What the on-device model measured for one capture. Stored with the record.
class SampleAnalysis {
  const SampleAnalysis({
    required this.modelVersion,
    required this.calibration,
    required this.count,
    required this.countPerFrame,
    required this.framesUsed,
    required this.boxes,
    required this.gutReadable,
    required this.gutTotal,
    required this.gutEmpty,
    required this.gutPartial,
    required this.gutFull,
    this.lengthMm,
    this.weightGrams,
    this.gutIndex,
  });

  factory SampleAnalysis.fromJson(Map<String, dynamic> json) => SampleAnalysis(
    modelVersion: json['modelVersion'] as String,
    calibration: json['calibration'] as String,
    count: json['count'] as int,
    countPerFrame: (json['countPerFrame'] as List).cast<int>(),
    framesUsed: json['framesUsed'] as int,
    boxes: [for (final v in json['boxes'] as List) (v as num).toDouble()],
    lengthMm: (json['lengthMm'] as num?)?.toDouble(),
    weightGrams: (json['weightGrams'] as num?)?.toDouble(),
    gutIndex: (json['gutIndex'] as num?)?.toDouble(),
    gutReadable: json['gutReadable'] as int,
    gutTotal: json['gutTotal'] as int,
    gutEmpty: json['gutEmpty'] as int,
    gutPartial: json['gutPartial'] as int,
    gutFull: json['gutFull'] as int,
  );

  final String modelVersion;

  /// `nominal`: scale taken from the box drawing, not from the markers.
  final String calibration;

  /// Mean over the usable frames, rounded.
  final int count;
  final List<int> countPerFrame;
  final int framesUsed;

  /// Boxes of the representative frame as left, top, right, bottom fractions
  /// of the (landscape) image.
  final List<double> boxes;

  final double? lengthMm;
  final double? weightGrams;

  /// Experimental. Mean share (0..1) of the abdomen with a visible gut line,
  /// over the animals where it could be read.
  final double? gutIndex;
  final int gutReadable;
  final int gutTotal;
  final int gutEmpty;
  final int gutPartial;
  final int gutFull;

  Map<String, dynamic> toJson() => {
    'modelVersion': modelVersion,
    'calibration': calibration,
    'count': count,
    'countPerFrame': countPerFrame,
    'framesUsed': framesUsed,
    'boxes': [for (final v in boxes) (v * 10000).round() / 10000],
    'lengthMm': lengthMm,
    'weightGrams': weightGrams,
    'gutIndex': gutIndex,
    'gutReadable': gutReadable,
    'gutTotal': gutTotal,
    'gutEmpty': gutEmpty,
    'gutPartial': gutPartial,
    'gutFull': gutFull,
  };
}

/// Result of analysing one capture, with the image to show and store.
class AnalysedSample {
  const AnalysedSample(this.analysis, this.jpeg, this.timings);

  final SampleAnalysis analysis;

  /// Representative frame, landscape, as stored with the record.
  final Uint8List jpeg;

  /// Milliseconds per stage, for performance checks.
  final Map<String, num> timings;
}
