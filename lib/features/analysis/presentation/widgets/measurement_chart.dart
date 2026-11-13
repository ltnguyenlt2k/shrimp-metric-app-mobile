import 'package:material_ui/material_ui.dart';

import '../../../../demo/sample_measurement.dart';

class MeasurementChart extends StatelessWidget {
  const MeasurementChart({
    required this.samples,
    required this.metric,
    super.key,
  });

  // Measurements are in chronological order.
  final List<SampleMeasurement> samples;
  final SampleMetric metric;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const Text('Chưa có lần đo trong khoảng này.');

    final theme = Theme.of(context);
    final values = samples.map(metric.value).toList();
    final upper = values.reduce((a, b) => a > b ? a : b) * 1.1;
    final start = samples.first.measuredAt;
    final span = samples.last.measuredAt.difference(start).inMilliseconds;
    final positions = [
      for (final sample in samples)
        span == 0
            ? 0.5
            : sample.measuredAt.difference(start).inMilliseconds / span,
    ];

    return Semantics(
      label:
          '${metric.label} theo thời gian. ${[for (final sample in samples) '${sample.dateLabel}: ${metric.format(metric.value(sample))}'].join('; ')}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đơn vị: ${metric.unit}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  height: 144,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final value in [upper, upper / 2, 0.0])
                        Text(
                          metric.format(value, includeUnit: false),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 144,
                    child: CustomPaint(
                      painter: _TrendPainter(
                        positions: positions,
                        values: values,
                        upper: upper,
                        color: theme.colorScheme.primary,
                        grid: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment:
                  samples.first.dateLabel == samples.last.dateLabel
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    samples.first.dateLabel,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (samples.first.dateLabel != samples.last.dateLabel)
                  Flexible(
                    child: Text(
                      samples.last.dateLabel,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.positions,
    required this.values,
    required this.upper,
    required this.color,
    required this.grid,
  });

  final List<double> positions;
  final List<double> values;
  final double upper;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 6.0;
    final height = size.height - 2 * inset;
    final width = size.width - 2 * inset;
    final gridPaint = Paint()..color = grid;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = inset + height * fraction;
      canvas.drawLine(Offset(inset, y), Offset(inset + width, y), gridPaint);
    }

    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          inset + width * positions[i],
          inset + height * (1 - (upper == 0 ? 0 : values[i] / upper)),
        ),
    ];
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5;
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], line);
    }
    for (final point in points) {
      canvas.drawCircle(point, 4, line);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.positions != positions ||
      oldDelegate.values != values ||
      oldDelegate.upper != upper ||
      oldDelegate.color != color ||
      oldDelegate.grid != grid;
}
