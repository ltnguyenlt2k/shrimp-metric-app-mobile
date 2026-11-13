import 'package:flutter/widgets.dart';

void main() {
  runApp(const ShrimpMetricApp());
}

class ShrimpMetricApp extends StatelessWidget {
  const ShrimpMetricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'ShrimpMetric',
      color: const Color(0xFF003E46),
      builder: (context, child) => const ColoredBox(
        color: Color(0xFF003E46),
        child: Center(
          child: Text(
            'ShrimpMetric',
            style: TextStyle(color: Color(0xFFFFF4DD)),
          ),
        ),
      ),
    );
  }
}
