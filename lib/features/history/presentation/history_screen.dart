import 'package:material_ui/material_ui.dart';

import '../../results/presentation/result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({required this.samples, super.key});

  final List<int> samples;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Lịch sử phân tích',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text('Dữ liệu mẫu'),
        const SizedBox(height: 16),
        for (final (index, count) in samples.indexed) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/demo/shrimp-tray.jpg',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            title: Text('Mẫu ${samples.length - index}'),
            subtitle: Text('$count con'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ResultScreen(count: count, saved: true),
              ),
            ),
          ),
          const Divider(),
        ],
      ],
    );
  }
}
