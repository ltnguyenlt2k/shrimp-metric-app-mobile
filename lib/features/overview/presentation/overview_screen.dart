import 'package:material_ui/material_ui.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    required this.count,
    required this.onCapture,
    required this.onHistory,
    super.key,
  });

  final int count;
  final VoidCallback onCapture;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text(
          'Phân tích mẫu tôm',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text('Chụp mẫu để ghi nhận số lượng tôm.'),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.8,
            child: Image.asset(
              'assets/demo/shrimp-tray.jpg',
              fit: BoxFit.cover,
              semanticLabel: 'Ảnh minh họa khay tôm',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onCapture,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Chụp mẫu'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
        const SizedBox(height: 24),
        Text('Lần phân tích gần nhất', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Material(
          color: const Color(0xFFE9F2EB),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: const Text('Dữ liệu mẫu'),
            subtitle: Text(
              '$count con',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: onHistory,
          ),
        ),
      ],
    );
  }
}
