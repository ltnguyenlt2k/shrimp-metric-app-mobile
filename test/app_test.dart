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
      for (final label in ['Chụp mẫu', 'Dùng ảnh mẫu', 'Lưu kết quả mẫu']) {
        final action = find.widgetWithText(FilledButton, label);
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(find.text('Lịch sử phân tích'), findsOneWidget);
      expect(find.text('48 con'), findsNWidgets(2));
      await tester.tap(find.text('Mẫu 3'));
      await tester.pumpAndSettle();
      final contribute = find.text('Đóng góp mẫu');
      await tester.ensureVisible(contribute);
      await tester.tap(contribute);
      await tester.pumpAndSettle();
      expect(find.text('Tính năng đang được chuẩn bị.'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(find.text('Hiệu chỉnh camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
