import 'package:material_ui/material_ui.dart';

import '../../../demo/sample_measurement.dart';
import '../../results/presentation/result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({required this.samples, super.key});

  final List<SampleMeasurement> samples;

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
        Text(
          '${samples.length} lần đo · Dữ liệu mẫu',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final sample in samples) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: sample.hasPreview
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/demo/shrimp-tray.jpg',
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
            trailing: const Icon(Icons.chevron_right),
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
      ],
    );
  }
}
