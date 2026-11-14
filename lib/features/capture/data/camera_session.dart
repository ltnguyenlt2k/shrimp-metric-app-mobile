import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../processing/domain/captured_frame.dart';

class CameraSession {
  CameraController? _controller;
  Completer<void>? _interrupted;

  CameraController? get controller => _controller;

  Future<void> open() async {
    final cameras = await availableCameras();
    final rear = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    if (rear.isEmpty) throw const CameraUnavailable();

    final controller = CameraController(
      rear.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void interrupt() {
    final interrupted = _interrupted;
    if (interrupted != null && !interrupted.isCompleted) interrupted.complete();
  }

  Future<List<CapturedFrame>> capture() async {
    final camera = _controller!;
    final frames = <CapturedFrame>[];
    final interrupted = _interrupted = Completer<void>();
    final clock = Stopwatch();
    final firstFrame = Completer<void>();
    const duration = Duration(milliseconds: 1800);
    const frameIntervalMs = 250;
    var lastFrameMs = -frameIntervalMs;
    final rotation = _rotation(camera);
    try {
      await camera
          .startImageStream((image) {
            if (!clock.isRunning) {
              clock.start();
              firstFrame.complete();
            }
            final elapsed = clock.elapsedMilliseconds;
            if (interrupted.isCompleted ||
                elapsed >= duration.inMilliseconds ||
                frames.length == 6 ||
                elapsed - lastFrameMs < frameIntervalMs) {
              return;
            }
            final format = switch (image.format.group) {
              ImageFormatGroup.yuv420 when image.planes.length == 3 =>
                FrameFormat.yuv420,
              ImageFormatGroup.bgra8888 when image.planes.length == 1 =>
                FrameFormat.bgra8888,
              _ => null,
            };
            if (format == null) return;
            frames.add(
              CapturedFrame(
                width: image.width,
                height: image.height,
                clockwiseRotation: rotation,
                format: format,
                planes: [
                  for (final plane in image.planes)
                    FramePlane(
                      plane.bytes,
                      plane.bytesPerRow,
                      plane.bytesPerPixel ?? 1,
                    ),
                ],
              ),
            );
            lastFrameMs = elapsed;
          })
          .timeout(const Duration(seconds: 3));
      // CameraX may rebind the preview before delivering the first frame.
      await Future.any([
        interrupted.future,
        firstFrame.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw const InsufficientFrames(),
        ),
      ]);
      // Bound the capture even if the device stops delivering frames.
      final remainingMs = duration.inMilliseconds - clock.elapsedMilliseconds;
      if (remainingMs > 0) {
        await Future.any([
          interrupted.future,
          Future<void>.delayed(Duration(milliseconds: remainingMs)),
        ]);
      }
    } finally {
      _interrupted = null;
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    }
    if (interrupted.isCompleted) return const [];
    if (frames.length < 5) throw const InsufficientFrames();
    return frames;
  }

  int _rotation(CameraController camera) {
    // AVFoundation rotates the streamed video buffers at the capture output.
    if (Platform.isIOS) return 0;
    final sensor = camera.description.sensorOrientation;
    final device = switch (camera.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return (sensor - device + 360) % 360;
  }

  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

class CameraUnavailable implements Exception {
  const CameraUnavailable();
}

class InsufficientFrames implements Exception {
  const InsufficientFrames();
}
