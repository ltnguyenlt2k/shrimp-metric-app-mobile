import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../demo/sample_preview.dart';
import '../../results/presentation/result_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  Timer? _timer;

  void _capture() {
    setState(() {
      _timer = Timer(const Duration(seconds: 2), _showResult);
    });
  }

  Future<void> _showResult() async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ResultScreen(count: demoDetectionCount),
      ),
    );
    if (!mounted) return;
    if (count != null) {
      Navigator.pop(context, count);
    } else {
      setState(() => _timer = null);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final processing = _timer != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B2426),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/demo/shrimp-tray.jpg',
              fit: BoxFit.cover,
              color: const Color(0xD00B2426),
              colorBlendMode: BlendMode.srcOver,
              excludeFromSemantics: true,
            ),
            SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Quay lại',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Chụp mẫu',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Camera mô phỏng',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF96E1CB),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const ClipRRect(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                child: SamplePreview(),
                              ),
                            ),
                          ),
                        ),
                        if (processing)
                          const ColoredBox(
                            color: Color(0xB3001719),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Color(0xFF96E1CB),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Đang xử lý ảnh mẫu…',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!processing) ...[
                    const Text(
                      'Giữ trọn khay trong khung',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    IconButton.filled(
                      tooltip: 'Chụp ảnh mẫu',
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(68),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF005D50),
                      ),
                      onPressed: _capture,
                      icon: const Icon(Icons.camera_alt_outlined, size: 30),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
