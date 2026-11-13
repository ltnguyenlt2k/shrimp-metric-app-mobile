import 'package:material_ui/material_ui.dart';

import '../../results/presentation/result_screen.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  Future<void> _review(BuildContext context) async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const ResultScreen(count: 48)),
    );
    if (context.mounted && count != null) Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chụp mẫu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Căn khay vào khung',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Đặt khay trên mặt phẳng và giữ điện thoại song song với khay.',
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/demo/shrimp-tray.jpg',
                fit: BoxFit.contain,
                semanticLabel: 'Ảnh minh họa khay tôm',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Ảnh minh họa · Bản xem trước'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _review(context),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Dùng ảnh mẫu'),
            ),
          ],
        ),
      ),
    );
  }
}
