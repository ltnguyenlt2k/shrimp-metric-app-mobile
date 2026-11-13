import 'package:material_ui/material_ui.dart';

class ShrimpMetricScrollBehavior extends MaterialScrollBehavior {
  const ShrimpMetricScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
