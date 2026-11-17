import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shrimp_metric/features/processing/domain/sample_analysis.dart';
import 'package:shrimp_metric/features/results/presentation/result_screen.dart';

SampleAnalysis _analysis({double? gutIndex = .72, int readable = 19}) =>
    SampleAnalysis(
      modelVersion: 'lite-v2-3a1979ee',
      calibration: 'nominal',
      count: 24,
      countPerFrame: const [24, 24, 23, 24, 25, 24],
      framesUsed: 6,
      boxes: const [.1, .2, .3, .4, .5, .5, .7, .8],
      lengthMm: 66.04,
      weightGrams: 2.418,
      gutIndex: gutIndex,
      gutReadable: readable,
      gutTotal: 24,
      gutEmpty: readable == 0 ? 0 : 2,
      gutPartial: readable == 0 ? 0 : 5,
      gutFull: readable == 0 ? 0 : 12,
    );

void main() {
  for (final size in [Size(360, 800), Size(411, 914), Size(450, 975)]) {
    testWidgets('Shows model results and gut fullness at ${size.width} px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(home: ResultScreen(count: 24, analysis: _analysis())),
      );
      expect(find.text('24 con'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Đầy 12 con'), 200);
      expect(find.text('Độ đầy ruột'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('Một phần 5 con'), findsOneWidget);
      expect(find.text('Rỗng 2 con'), findsOneWidget);
      expect(find.textContaining('Đọc được 19/24 con'), findsOneWidget);
      expect(find.textContaining('Chỉ số thử nghiệm'), findsOneWidget);
      expect(find.textContaining('chưa hiệu chỉnh bằng marker'), findsOneWidget);
      expect(find.text('2,418'), findsOneWidget);
      expect(find.text('66,0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Says so when no gut could be read', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          count: 24,
          analysis: _analysis(gutIndex: null, readable: 0),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Độ đầy ruột'), 200);
    await tester.scrollUntilVisible(
      find.text('Chưa đọc được độ đầy ruột ở mẫu này.'),
      100,
    );
    expect(find.text('Đầy 0 con'), findsNothing);
  });

  test('Analysis survives being stored with a record', () {
    final restored = SampleAnalysis.fromJson(_analysis().toJson());
    expect(restored.count, 24);
    expect(restored.boxes.length, 8);
    expect(restored.gutIndex, .72);
    expect(restored.lengthMm, 66.04);
  });
}
