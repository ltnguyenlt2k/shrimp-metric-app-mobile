import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../demo/sample_preview.dart';
import '../demo/sample_measurement.dart';
import '../features/analysis/presentation/analysis_screen.dart';
import '../features/capture/presentation/capture_screen.dart';
import '../features/capture/presentation/demo_capture_screen.dart';
import '../features/history/data/measurement_store.dart';
import '../features/results/domain/local_measurement.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/overview/presentation/overview_screen.dart';
import '../features/results/presentation/result_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

import 'shrimp_metric_scroll_behavior.dart';

class ShrimpMetricApp extends StatelessWidget {
  const ShrimpMetricApp({this.demoCapture = false, super.key});

  final bool demoCapture;

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
        listTileTheme: const ListTileThemeData(minTileHeight: 56),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAF6),
      ),
      home: _Home(demoCapture: demoCapture),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.demoCapture});

  final bool demoCapture;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int index = 0;
  SampleMetric _analysisMetric = SampleMetric.count;
  int _nextSampleId = 5;
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

  final _store = MeasurementStore();
  late final Future<void> _historyReady;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _historyReady = widget.demoCapture ? Future.value() : _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final saved = await _store.load();
      if (!mounted) return;
      setState(() {
        samples.insertAll(0, saved.map(_asSample));
        for (final entry in saved) {
          if (entry.sampleNumber >= _nextSampleId) {
            _nextSampleId = entry.sampleNumber + 1;
          }
        }
      });
    } catch (_) {
      // The built-in samples remain available if local storage cannot be read.
    }
  }

  SampleMeasurement _asSample(LocalMeasurement saved) => SampleMeasurement(
    id: saved.sampleNumber,
    count: saved.count,
    measuredAt: saved.measuredAt,
    hasPreview: true,
    imagePath: saved.imagePath,
    storageId: saved.id,
  );

  Future<void> _deleteSample(int id) async {
    final sample = samples.firstWhere((sample) => sample.id == id);
    try {
      if (sample.storageId case final storageId?) {
        await _store.delete(storageId);
      }
      if (mounted) {
        setState(() => samples.remove(sample));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xóa được lần đo. Hãy thử lại.')),
      );
    }
  }

  Future<void> capture() async {
    if (!widget.demoCapture) {
      if (_capturing) return;
      _capturing = true;
      final navigator = Navigator.of(context);
      LocalMeasurement? saved;
      try {
        await _historyReady;
        if (!mounted) return;
        saved = await navigator.push<LocalMeasurement>(
          MaterialPageRoute(
            builder: (_) =>
                CaptureScreen(store: _store, sampleNumber: _nextSampleId),
          ),
        );
      } finally {
        _capturing = false;
      }
      if (!mounted || saved == null) return;
      final measurement = saved;
      setState(() {
        samples.insert(0, _asSample(measurement));
        _nextSampleId++;
        index = 1;
      });
      return;
    }
    final count = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const DemoCaptureScreen()));
    if (!mounted || count == null) return;
    setState(() {
      samples.insert(
        0,
        SampleMeasurement(
          id: _nextSampleId++,
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
                  onAnalysis: () => setState(() {
                    _analysisMetric = SampleMetric.size;
                    index = 2;
                  }),
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
                1 => HistoryScreen(samples: samples, onDelete: _deleteSample),
                2 => AnalysisScreen(
                  samples: samples,
                  initialMetric: _analysisMetric,
                ),
                _ => const SettingsScreen(),
              },
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() {
            if (value == 2 && index != 2) _analysisMetric = SampleMetric.count;
            index = value;
          }),
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
