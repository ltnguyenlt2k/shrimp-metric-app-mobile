import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../demo/sample_preview.dart';
import '../../history/data/measurement_store.dart';
import '../../processing/application/prepare_sample.dart';
import '../../results/domain/local_measurement.dart';
import '../../results/presentation/result_screen.dart';
import '../data/camera_session.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    required this.store,
    required this.sampleNumber,
    super.key,
  });

  final MeasurementStore store;
  final int sampleNumber;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  final _session = CameraSession();
  Future<void> _operation = Future.value();
  var _active = true;
  var _opening = true;
  var _busy = false;
  var _reviewing = false;
  var _generation = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  void _enqueue(Future<void> Function() action) {
    _operation = _operation.then((_) => action()).catchError((Object error) {
      if (!mounted || !_active) return;
      setState(() {
        _opening = false;
        _busy = false;
        _message = 'Camera gặp lỗi. Hãy thử mở lại.';
      });
    });
  }

  void _open() {
    if (!mounted || !_active || _reviewing) return;
    final generation = _generation;
    setState(() {
      _opening = true;
      _message = null;
    });
    _enqueue(() async {
      if (!mounted || !_active || _reviewing || generation != _generation) {
        return;
      }
      try {
        await _session.close();
        await _session.open();
      } on CameraException catch (error) {
        _message = switch (error.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
            'Hãy cho phép ShrimpMetric dùng camera trong Cài đặt điện thoại.',
          'CameraAccessRestricted' => 'Camera bị giới hạn trên thiết bị này.',
          _ => 'Không mở được camera. Hãy thử lại.',
        };
      } on CameraUnavailable {
        _message = 'Thiết bị không có camera sau khả dụng.';
      }
      if (mounted && _active && generation == _generation) {
        setState(() => _opening = false);
      }
    });
  }

  void _capture() {
    if (_busy || _opening || !_active) return;
    final generation = _generation;
    final measuredAt = DateTime.now();
    setState(() {
      _busy = true;
      _message = null;
    });
    _enqueue(() async {
      if (!_active || generation != _generation) return;
      try {
        final frames = await _session.capture();
        if (!mounted ||
            !_active ||
            frames.isEmpty ||
            generation != _generation) {
          return;
        }
        // Remove the preview before disposing its native controller.
        final navigator = Navigator.of(context);
        setState(() => _reviewing = true);
        await _session.close();
        final frameCount = frames.length;
        final jpeg = await prepareSample(frames);
        if (!mounted || !_active || generation != _generation) return;
        // The capture operation must finish while the result route is open.
        unawaited(
          navigator
              .push<LocalMeasurement>(
                MaterialPageRoute(
                  builder: (context) => ResultScreen(
                    count: demoDetectionCount,
                    jpeg: jpeg,
                    onSave: () async {
                      final result = await widget.store.save(
                        jpeg: jpeg,
                        count: demoDetectionCount,
                        sampleNumber: widget.sampleNumber,
                        frameCount: frameCount,
                        measuredAt: measuredAt,
                      );
                      if (context.mounted) Navigator.pop(context, result);
                    },
                  ),
                ),
              )
              .then((result) {
                if (!mounted) return;
                if (result != null) {
                  navigator.pop(result);
                } else {
                  setState(() {
                    _reviewing = false;
                    _busy = false;
                  });
                  _open();
                }
              }),
        );
      } on InsufficientFrames {
        if (!mounted || !_active || generation != _generation) return;
        setState(() {
          _busy = false;
          _message = 'Camera chưa lấy đủ ảnh. Giữ yên điện thoại và chụp lại.';
        });
      } catch (_) {
        if (!mounted || !_active || generation != _generation) return;
        setState(() {
          _reviewing = false;
          _busy = false;
          _message = 'Không thể chuẩn bị ảnh. Hãy thử lại.';
        });
        await _session.close();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    // Android permission prompts may change focus without backgrounding.
    if (state == AppLifecycleState.inactive && _opening) return;
    if (active == _active) return;
    setState(() {
      _active = active;
      _generation++;
      if (!_reviewing) _busy = false;
    });
    if (active) {
      if (_reviewing && ModalRoute.of(context)?.isCurrent == true) {
        setState(() {
          _reviewing = false;
          _busy = false;
        });
      }
      _open();
    } else {
      _session.interrupt();
      _enqueue(_session.close);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _active = false;
    _generation++;
    _session.interrupt();
    _enqueue(_session.close);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final processing = _busy;
    final controller = _session.controller;
    final ready =
        _active &&
        !_opening &&
        !_reviewing &&
        controller?.value.isInitialized == true;
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
                      Expanded(
                        child: Text(
                          'Chụp mẫu',
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text('Camera', style: TextStyle(color: Colors.white70)),
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
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                child: ready
                                    ? CameraPreview(controller!)
                                    : const SizedBox.shrink(),
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
                    Text(
                      _message ?? 'Giữ trọn khay trong khung',
                      textAlign: TextAlign.center,
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
                      onPressed: ready ? _capture : (_opening ? null : _open),
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
