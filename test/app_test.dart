import 'package:flutter_test/flutter_test.dart';
import 'package:shrimp_metric/main.dart';

void main() {
  testWidgets('Launches ShrimpMetric', (tester) async {
    await tester.pumpWidget(const ShrimpMetricApp());
    expect(find.text('ShrimpMetric'), findsOneWidget);
  });
}
