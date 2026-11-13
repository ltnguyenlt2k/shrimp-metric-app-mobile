import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../features/capture/presentation/capture_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/overview/presentation/overview_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

class ShrimpMetricApp extends StatelessWidget {
  const ShrimpMetricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShrimpMetric',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00675D)),
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
  final samples = <int>[48, 35];

  void capture() async {
    final count = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => const CaptureScreen()));
    if (!mounted || count == null) return;
    setState(() {
      samples.insert(0, count);
      index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FAF6),
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
                child: Text(
                  'ShrimpMetric',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
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
                  count: samples.first,
                  onCapture: capture,
                  onHistory: () => setState(() => index = 1),
                ),
                1 => HistoryScreen(samples: samples),
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
              icon: Icon(Icons.tune_rounded),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }
}
