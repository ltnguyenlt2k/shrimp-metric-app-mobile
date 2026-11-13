import 'package:material_ui/material_ui.dart';

import '../../../demo/sample_measurement.dart';
import '../../analysis/presentation/widgets/measurement_chart.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    required this.samples,
    required this.onCapture,
    required this.onHistory,
    required this.onAnalysis,
    super.key,
  });

  final List<SampleMeasurement> samples;
  final VoidCallback onCapture;
  final VoidCallback onHistory;
  final VoidCallback onAnalysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = samples.firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Nhật ký đo tôm', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('Dữ liệu mẫu', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCapture,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Chụp mẫu'),
        ),
        const SizedBox(height: 24),
        if (latest == null)
          const Text('Chưa có lần đo. Chụp mẫu để bắt đầu.')
        else ...[
          Text('Lần đo gần nhất', style: theme.textTheme.titleLarge),
          Text(
            '${latest.dateLabel} · ${latest.timeLabel}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final metric in SampleMetric.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(metric.label)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              metric.format(metric.value(latest)),
                              textAlign: TextAlign.end,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: onHistory,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Xem kết quả chi tiết'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Cỡ tôm theo thời gian', style: theme.textTheme.titleLarge),
          Text('${samples.length} lần đo', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          MeasurementChart(
            samples: samples.reversed.toList(),
            metric: SampleMetric.size,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onAnalysis,
              icon: const Icon(Icons.show_chart),
              label: const Text('Mở phân tích'),
            ),
          ),
        ],
      ],
    );
  }
}
