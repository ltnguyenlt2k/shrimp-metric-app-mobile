import 'package:material_ui/material_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _show(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Cài đặt', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 20),
        Text('Thiết lập đo', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.center_focus_strong),
          title: const Text('Hiệu chỉnh camera'),
          subtitle: const Text('Căn khay và ánh sáng'),
          trailing: const Icon(Icons.chevron_right, semanticLabel: 'Mở'),
          onTap: () => _show(
            context,
            'Hiệu chỉnh camera',
            'Đặt khay trên mặt phẳng, dùng ánh sáng đều và giữ camera song song với khay.',
          ),
        ),
        const SizedBox(height: 20),
        Text('Ứng dụng', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language),
          title: const Text('Ngôn ngữ'),
          subtitle: const Text('Tiếng Việt'),
          trailing: const Icon(Icons.chevron_right, semanticLabel: 'Mở'),
          onTap: () =>
              _show(context, 'Ngôn ngữ', 'Bản xem trước dùng tiếng Việt.'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('Thông tin app'),
          subtitle: const Text('ShrimpMetric · 0.1.0'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('Giấy phép nguồn mở'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'ShrimpMetric',
            applicationVersion: '0.1.0',
          ),
        ),
      ],
    );
  }
}
