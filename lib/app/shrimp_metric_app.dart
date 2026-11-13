import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../demo/sample_preview.dart';
import '../demo/sample_measurement.dart';
import '../features/analysis/presentation/analysis_screen.dart';
import '../features/capture/presentation/capture_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/overview/presentation/overview_screen.dart';
import '../features/results/presentation/result_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

import 'shrimp_metric_scroll_behavior.dart';

class ShrimpMetricApp extends StatelessWidget {
  const ShrimpMetricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShrimpMetric',
      scrollBehavior: const ShrimpMetricScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 26,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            fontSize: 19,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(fontSize: 16, height: 1.4),
          bodyMedium: TextStyle(fontSize: 15, height: 1.4),
          bodySmall: TextStyle(fontSize: 13, height: 1.4),
          labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00675D)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAF6),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: TextStyle(
            color: Color(0xFF14312E),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 56,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAF6),
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int index = 0;
  late final samples = [
    SampleMeasurement(
      id: 4,
      count: demoDetectionCount,
      measuredAt: DateTime.now().subtract(const Duration(days: 1)),
      hasPreview: true,
    ),
    SampleMeasurement(
      id: 3,
      count: 35,
      averageWeightGrams: 0.264,
      averageLengthMm: 28.6,
      measuredAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    SampleMeasurement(
      id: 2,
      count: 36,
      averageWeightGrams: 0.211,
      averageLengthMm: 25.4,
      measuredAt: DateTime.now().subtract(const Duration(days: 16)),
    ),
    SampleMeasurement(
      id: 1,
      count: 42,
      averageWeightGrams: 0.173,
      averageLengthMm: 22.1,
      measuredAt: DateTime.now().subtract(const Duration(days: 23)),
    ),
  ];

  void capture() async {
    final count = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => const CaptureScreen()));
    if (!mounted || count == null) return;
    setState(() {
      samples.insert(
        0,
        SampleMeasurement(
          id: samples.length + 1,
          count: count,
          measuredAt: DateTime.now(),
          hasPreview: true,
        ),
      );
      index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/branding/shrimpmetric-icon.png',
                  width: 34,
                  height: 34,
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text('ShrimpMetric', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: switch (index) {
                0 => OverviewScreen(
                  samples: samples,
                  onAnalysis: () => setState(() => index = 2),
                  onCapture: capture,
                  onHistory: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        count: samples.first.count,
                        measurement: samples.first,
                      ),
                    ),
                  ),
                ),
                1 => HistoryScreen(samples: samples),
                2 => AnalysisScreen(samples: samples),
                _ => const SettingsScreen(),
              },
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'Lịch sử',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Phân tích',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }
}
