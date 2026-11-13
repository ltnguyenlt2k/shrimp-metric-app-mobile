import 'package:flutter/foundation.dart';
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
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      await tester.tap(find.text('38 con'));
      await tester.pumpAndSettle();
      expect(find.text('Nhật ký đo tôm'), findsOneWidget);
      final details = find.widgetWithText(
        OutlinedButton,
        'Xem kết quả chi tiết',
      );
      await tester.scrollUntilVisible(details, 100);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Kết quả'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final capture = find.widgetWithText(FilledButton, 'Chụp mẫu');
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(capture);
      await tester.pumpAndSettle();
      await tester.tap(capture);
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
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử phân tích'), findsOneWidget);
      await tester.tap(find.text('Mẫu 5 · 38 con'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử phân tích'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Xem mẫu').first);
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
      expect(find.text('5 lần đo · 189 con đã đếm'), findsOneWidget);
      final dateChip = find.widgetWithText(ChoiceChip, '7 ngày');
      final dateBounds = tester.getRect(dateChip);
      await tester.tap(dateChip);
      await tester.pumpAndSettle();
      expect(tester.getRect(dateChip), dateBounds);
      expect(tester.widget<ChoiceChip>(dateChip).showCheckmark, isFalse);
      final average = find.text('Số đếm trung bình mỗi mẫu');
      await tester.scrollUntilVisible(average, 120);
      expect(average, findsOneWidget);
      final sizeMetric = find.widgetWithText(ChoiceChip, 'Cỡ tôm');
      await tester.ensureVisible(sizeMetric);
      await tester.pumpAndSettle();
      final metricBounds = tester.getRect(sizeMetric);
      await tester.tap(sizeMetric);
      await tester.pumpAndSettle();
      expect(tester.getRect(sizeMetric), metricBounds);
      expect(tester.widget<ChoiceChip>(sizeMetric).showCheckmark, isFalse);
      await tester.scrollUntilVisible(find.text('2.193 con/kg').first, 100);
      expect(find.text('2.193 con/kg'), findsWidgets);

      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(find.text('Hiệu chỉnh camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('License list preserves padding with large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ShrimpMetricApp());
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks(['Test package'], 'Sample license'),
      ),
    );
    addTearDown(LicenseRegistry.reset);
    await tester.scrollUntilVisible(find.text('Giấy phép nguồn mở'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giấy phép nguồn mở'));
    await tester.pumpAndSettle();
    final licensePage = find.byType(LicensePage);
    expect(licensePage, findsOneWidget);
    final row = find
        .descendant(of: licensePage, matching: find.byType(ListTile))
        .first;
    final title = tester.widget<ListTile>(row).title!;
    expect(
      tester.getTopLeft(find.byWidget(title)).dx,
      greaterThanOrEqualTo(16),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Giấy phép nguồn mở'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Confirms deletion and handles empty history', (tester) async {
    await tester.pumpWidget(const ShrimpMetricApp());
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Xóa mẫu 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Xóa mẫu 4'), findsOneWidget);

    for (final id in [4, 3, 2, 1]) {
      await tester.tap(find.byTooltip('Xóa mẫu $id'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa mẫu'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Xóa mẫu $id'), findsNothing);
    }

    expect(find.text('0 lần đo · Dữ liệu mẫu'), findsOneWidget);
    await tester.tap(find.text('Phân tích'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lần đo trong khoảng này.'), findsOneWidget);
    await tester.tap(find.text('Tổng quan'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lần đo. Chụp mẫu để bắt đầu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
