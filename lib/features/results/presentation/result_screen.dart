import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../../demo/sample_preview.dart';
import '../../../demo/sample_measurement.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    required this.count,
    this.measurement,
    this.jpeg,
    this.onSave,
    super.key,
  });

  final int count;
  final Uint8List? jpeg;
  final Future<void> Function()? onSave;
  final SampleMeasurement? measurement;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool marked = true;
  bool _saving = false;

  Future<void> _save() async {
    final save = widget.onSave;
    if (save == null) {
      Navigator.pop(context, widget.count);
      return;
    }
    setState(() => _saving = true);
    try {
      await save();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lưu được kết quả. Hãy thử lại.')),
      );
    }
  }

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
    final ImageProvider? provider = switch ((widget.jpeg, sample.imagePath)) {
      (final bytes?, _) => MemoryImage(bytes),
      (_, final path?) => FileImage(File(path)),
      _ => null,
    };
    Widget preview({required bool marked, required double width}) {
      return SamplePreview(
        marked: marked,
        photo: provider == null
            ? null
            : Image(
                image: ResizeImage.resizeIfNeeded(
                  (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
                  null,
                  provider,
                ),
                fit: BoxFit.contain,
                semanticLabel: 'Ảnh mẫu gốc',
                excludeFromSemantics: width == 42,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.image_not_supported_outlined),
              ),
      );
    }

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kết quả')),
        bottomNavigationBar: widget.measurement == null
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Lưu kết quả mẫu'),
                ),
              )
            : null,
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
                    SizedBox(
                      width: 42,
                      child: preview(marked: false, width: 42),
                    ),
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
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Tổng số tôm'),
                  Text(
                    '${widget.count} con',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (hasPreview)
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: preview(
                    marked: marked,
                    width: MediaQuery.sizeOf(context).width - 40,
                  ),
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
      ),
    );
  }
}
