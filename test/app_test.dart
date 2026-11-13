import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shrimp_metric/app/shrimp_metric_app.dart';

void main() {
  for (final size in [Size(360, 800), Size(411, 914), Size(450, 975)]) {
    testWidgets('Reviews a sample on a ${size.width} px viewport', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const ShrimpMetricApp());
      await tester.tap(find.widgetWithText(FilledButton, 'Chụp mẫu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chụp ảnh mẫu'));
      await tester.pump();
      expect(find.text('Đang xử lý ảnh mẫu…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final overlay = find.widgetWithText(
        SwitchListTile,
        'Hiện khung nhận diện',
      );
      await tester.scrollUntilVisible(overlay, 120);
      expect(tester.widget<SwitchListTile>(overlay).value, isTrue);
      await tester.pumpAndSettle();
      await tester.tap(overlay);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(overlay).value, isFalse);
      final save = find.text('Lưu kết quả mẫu');
      await tester.scrollUntilVisible(save, 100);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử phân tích'), findsOneWidget);
      await tester.tap(find.text('Mẫu 3 · 38 con'));
      await tester.pumpAndSettle();
      final contribute = find.text('Đóng góp mẫu');
      await tester.scrollUntilVisible(contribute, 120);
      await tester.pumpAndSettle();
      await tester.tap(contribute);
      await tester.pumpAndSettle();
      expect(find.text('Tính năng đang được chuẩn bị.'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phân tích'));
      await tester.pumpAndSettle();
      expect(find.text('3 lần đo · 111 con đã đếm'), findsOneWidget);
      await tester.tap(find.text('7 ngày'));
      await tester.pumpAndSettle();
      final average = find.text('Số đếm trung bình mỗi mẫu');
      await tester.scrollUntilVisible(average, 120);
      expect(average, findsOneWidget);
      final sizeMetric = find.widgetWithText(ChoiceChip, 'Cỡ tôm');
      await tester.ensureVisible(sizeMetric);
      await tester.pumpAndSettle();
      await tester.tap(sizeMetric);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('2.193 con/kg').first, 100);
      expect(find.text('2.193 con/kg'), findsWidgets);

      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(find.text('Hiệu chỉnh camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
