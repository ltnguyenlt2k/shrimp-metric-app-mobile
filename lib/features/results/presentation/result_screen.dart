import 'package:material_ui/material_ui.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.count, this.saved = false, super.key});

  final int count;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/demo/shrimp-tray.jpg',
                fit: BoxFit.contain,
                semanticLabel: 'Ảnh minh họa khay tôm',
              ),
            ),
            const SizedBox(height: 20),
            const Text('Dữ liệu mẫu · Số lượng tôm'),
            Text(
              '$count con',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            if (!saved)
              FilledButton(
                onPressed: () => Navigator.pop(context, count),
                child: const Text('Lưu kết quả mẫu'),
              ),
            if (saved)
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
        ),
      ),
    );
  }
}
