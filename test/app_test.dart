import 'package:flutter_test/flutter_test.dart';
import 'package:shrimp_metric/app/shrimp_metric_app.dart';

void main() {
  testWidgets('Launches ShrimpMetric', (tester) async {
    await tester.pumpWidget(const ShrimpMetricApp());
    expect(find.text('ShrimpMetric'), findsOneWidget);
  });
}
