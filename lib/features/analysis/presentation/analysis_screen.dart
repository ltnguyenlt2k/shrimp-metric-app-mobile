import 'package:material_ui/material_ui.dart';

import '../../../demo/sample_measurement.dart';
import '../../results/presentation/result_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({required this.samples, super.key});

  final List<SampleMeasurement> samples;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int? _days;
  SampleMetric _metric = SampleMetric.count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = _days;
    final start = days == null
        ? null
        : DateTime(now.year, now.month, now.day - days + 1);
    final samples = widget.samples.reversed
        .where((sample) => start == null || !sample.measuredAt.isBefore(start))
        .toList();
    final total = samples.fold(0, (sum, sample) => sum + sample.count);
    final peak = samples.fold(0.0, (max, sample) {
      final value = _metric.value(sample);
      return value > max ? value : max;
    });
    final metricTotal = samples.fold(
      0.0,
      (sum, sample) => sum + _metric.value(sample),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Phân tích dữ liệu', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text('Dữ liệu mẫu'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in [
              (null, 'Tất cả'),
              (7, '7 ngày'),
              (30, '30 ngày'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _days == value,
                onSelected: (_) => setState(() => _days = value),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (samples.isEmpty)
          const Text('Chưa có lần đo trong khoảng này.')
        else ...[
          Text('${samples.first.dateLabel} – ${samples.last.dateLabel}'),
          const SizedBox(height: 12),
          Text('${samples.length} lần đo · $total con đã đếm'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in SampleMetric.values)
                ChoiceChip(
                  label: Text(metric.label),
                  selected: _metric == metric,
                  onSelected: (_) => setState(() => _metric = metric),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _metric == SampleMetric.count
                ? '${(total / samples.length).toStringAsFixed(1).replaceAll('.', ',')} con'
                : _metric.format(metricTotal / samples.length),
            style: theme.textTheme.displaySmall,
          ),
          Text(
            _metric == SampleMetric.count
                ? 'Số đếm trung bình mỗi mẫu'
                : 'Trung bình theo lần đo',
          ),
          const SizedBox(height: 24),
          Text(
            '${_metric.label} theo lần đo',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final sample in samples)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${sample.dateLabel} · Mẫu ${sample.id}'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: peak == 0 ? 0 : _metric.value(sample) / peak,
                    minHeight: 8,
                  ),
                ),
              ),
              trailing: Text(_metric.format(_metric.value(sample))),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ResultScreen(count: sample.count, measurement: sample),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
