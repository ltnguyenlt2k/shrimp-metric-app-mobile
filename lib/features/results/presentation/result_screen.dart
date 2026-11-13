import 'package:material_ui/material_ui.dart';

import '../../../demo/sample_preview.dart';
import '../../../demo/sample_measurement.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.count, this.measurement, super.key});

  final int count;
  final SampleMeasurement? measurement;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool marked = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sample =
        widget.measurement ??
        SampleMeasurement(
          id: 0,
          count: widget.count,
          measuredAt: DateTime.now(),
        );
    final hasPreview = widget.measurement?.hasPreview ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.measurement case final sample?) ...[
              Text(
                'Mẫu ${sample.id} · ${sample.dateLabel} lúc ${sample.timeLabel}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
            ],
            if (hasPreview) ...[
              Row(
                children: [
                  const SizedBox(width: 64, child: SamplePreview()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ảnh mẫu gốc',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const Text('Tổng số tôm · Dữ liệu mô phỏng'),
            Text(
              '${widget.count} con',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (hasPreview)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SamplePreview(marked: marked),
              ),
            const SizedBox(height: 16),
            Text('Chỉ số mẫu', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                const gap = 8.0;
                final columns = constraints.maxWidth >= 306 * scale ? 3 : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final metric in [
                      SampleMetric.size,
                      SampleMetric.weight,
                      SampleMetric.length,
                    ])
                      SizedBox(
                        width: width,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F2EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metric.format(
                                    metric.value(sample),
                                    includeUnit: false,
                                  ),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${metric.label} (${metric.unit})',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (hasPreview)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hiện khung nhận diện'),
                value: marked,
                onChanged: (value) => setState(() => marked = value),
              ),
            const SizedBox(height: 12),
            if (widget.measurement == null)
              FilledButton(
                onPressed: () => Navigator.pop(context, widget.count),
                child: const Text('Lưu kết quả mẫu'),
              ),
            if (widget.measurement != null) ...[
              const Divider(),
              OutlinedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Đóng góp mẫu'),
                    content: const Text('Tính năng đang được chuẩn bị.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Đóng góp mẫu'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
