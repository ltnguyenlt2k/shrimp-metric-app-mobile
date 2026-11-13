import 'package:material_ui/material_ui.dart';

import '../../../demo/sample_measurement.dart';
import '../../results/presentation/result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    required this.samples,
    required this.onDelete,
    super.key,
  });

  final List<SampleMeasurement> samples;

  final ValueChanged<int> onDelete;

  Future<void> _confirmDelete(
    BuildContext context,
    SampleMeasurement sample,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa mẫu ${sample.id}?'),
        content: const Text('Lần đo này sẽ bị xóa khỏi lịch sử và biểu đồ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa mẫu'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) onDelete(sample.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnailPixels = (52 * MediaQuery.devicePixelRatioOf(context))
        .ceil();
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: samples.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lịch sử phân tích',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${samples.length} lần đo · Dữ liệu mẫu',
                  style: theme.textTheme.bodySmall,
                ),
                if (samples.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có lần đo. Bạn có thể chụp mẫu từ Tổng quan.',
                  ),
                ],
              ],
            ),
          );
        }
        final sample = samples[index - 1];
        return Column(
          key: ValueKey(sample.id),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: sample.hasPreview
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/demo/shrimp-tray.jpg',
                        cacheWidth: thumbnailPixels,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    )
                  : const SizedBox.square(
                      dimension: 52,
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
              title: Text('Mẫu ${sample.id} · ${sample.count} con'),
              subtitle: Text('${sample.dateLabel} · ${sample.timeLabel}'),
              trailing: IconButton(
                tooltip: 'Xóa mẫu ${sample.id}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, sample),
              ),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ResultScreen(count: sample.count, measurement: sample),
                ),
              ),
            ),
            const Divider(),
          ],
        );
      },
    );
  }
}
