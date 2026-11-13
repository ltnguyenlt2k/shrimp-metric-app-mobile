import 'package:flutter/widgets.dart';

import '../features/overview/presentation/overview_screen.dart';

class ShrimpMetricApp extends StatelessWidget {
  const ShrimpMetricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'ShrimpMetric',
      color: const Color(0xFF003E46),
      builder: (context, child) => const OverviewScreen(),
    );
  }
}
