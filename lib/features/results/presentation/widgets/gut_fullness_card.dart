import 'package:material_ui/material_ui.dart';

import '../../../processing/domain/sample_analysis.dart';

/// Gut fullness of one sample: the mean index and how many animals fall in
/// each level. The index is experimental and labelled as such.
class GutFullnessCard extends StatelessWidget {
  const GutFullnessCard({required this.analysis, super.key});

  final SampleAnalysis analysis;

  static const _full = Color(0xFF00675D);
  static const _partial = Color(0xFF6FB7A8);
  static const _empty = Color(0xFFD3DDD8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readable = analysis.gutReadable;
    final unreadable = analysis.gutTotal - readable;
    final levels = [
      ('Đầy', analysis.gutFull, _full),
      ('Một phần', analysis.gutPartial, _partial),
      ('Rỗng', analysis.gutEmpty, _empty),
    ];
    final outline = theme.colorScheme.outline;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE9F2EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (analysis.gutIndex case final index? when readable > 0) ...[
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${(index * 100).round()}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Mức đầy trung bình',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(color: outline),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (_, count, color) in levels)
                            if (count > 0)
                              Expanded(
                                flex: count,
                                child: ColoredBox(color: color),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final (label, count, color) in levels)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(color: outline),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('$label $count con'),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                unreadable > 0
                    ? 'Đọc được $readable/${analysis.gutTotal} con. '
                          '$unreadable con không đọc được do thân tối, quá nhỏ hoặc chạm mép ảnh.'
                    : 'Đọc được $readable/${analysis.gutTotal} con.',
                style: theme.textTheme.bodySmall,
              ),
            ] else
              const Text('Chưa đọc được độ đầy ruột ở mẫu này.'),
            const SizedBox(height: 4),
            Text(
              'Chỉ số thử nghiệm, chưa đối chiếu với đánh giá bằng mắt.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
