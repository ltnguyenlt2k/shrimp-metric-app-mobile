import 'package:flutter/widgets.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF003E46),
      child: Center(
        child: Text('ShrimpMetric', style: TextStyle(color: Color(0xFFFFF4DD))),
      ),
    );
  }
}
