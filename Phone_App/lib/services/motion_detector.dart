// lib/services/motion_detector.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef MotionStatusCallback = void Function(String status);
typedef MotionDetectedCallback = void Function(Uint8List imageBytes);
typedef MotionErrorCallback = void Function(String error);

class MotionDetector {
  static const _pushoverUrl = 'https://api.pushover.net/1/messages.json';
  static const _analysisIntervalMs = 1500;
  static const _blockCols = 8;
  static const _blockRows = 6;
  static const _yDiffThreshold = 18;

  CameraController? _controller;
  bool _isActive = false;
  bool _disposed = false;
  Timer? _analysisTimer;

  Uint8List? _prevGrid;
  DateTime? _lastDetectionTime;

  final AppSettings _settings;
  final MotionStatusCallback? onStatusChanged;
  final MotionDetectedCallback? onMotionDetected;
  final MotionErrorCallback? onError;

  bool get isActive => _isActive;

  MotionDetector({
    required AppSettings settings,
    this.onStatusChanged,
    this.onMotionDetected,
    this.onError,
  }) : _settings = settings;

  Future<bool> start() async {
    if (_isActive) return true;
    if (_disposed) return false;

    try {
      final cameras = await availableCameras();
      CameraDescription? frontCamera;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          frontCamera = cam;
          break;
        }
      }

      if (frontCamera == null) {
        _reportError('No front camera found');
        return false;
      }

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (_disposed) {
        await _controller!.dispose();
        _controller = null;
        return false;
      }

      await _controller!.startImageStream(_onFrameAvailable);
      _isActive = true;
      _prevGrid = null;
      _lastDetectionTime = null;
      _notifyStatus('STANDBY');

      _analysisTimer = Timer.periodic(
        const Duration(milliseconds: _analysisIntervalMs),
        (_) => _runAnalysisTick(),
      );

      return true;
    } catch (e) {
      _reportError('Camera init failed: $e');
      await _cleanup();
      return false;
    }
  }

  Future<void> stop() async {
    await _cleanup();
    _notifyStatus('IDLE');
  }

  Future<void> _cleanup() async {
    _isActive = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
    _prevGrid = null;
  }

  void _onFrameAvailable(CameraImage image) {
    if (!_isActive || _disposed) return;

    try {
      final grid = _buildGridFromYPlane(image);
      if (grid == null) return;

      if (_prevGrid == null || _lastDetectionTime == null) {
        _prevGrid = grid;
        return;
      }

      final now = DateTime.now();
      final diffSinceLast = now.difference(_lastDetectionTime!);
      if (diffSinceLast.inMilliseconds < _settings.motionDebounceMs) {
        _prevGrid = grid;
        return;
      }

      final diff = _compareGrids(_prevGrid!, grid);
      if (diff > _settings.motionSensitivity) {
        _lastDetectionTime = now;
        _prevGrid = grid;
        _notifyStatus('MOTION');
        _captureAndSend();
      } else {
        _prevGrid = grid;
      }
    } on Object catch (_) {
      // swallow frame errors so stream doesn't crash
    }
  }

  Uint8List? _buildGridFromYPlane(CameraImage image) {
    try {
      final yPlane = image.planes[0];
      final width = image.width;
      final height = image.height;

      final blockW = width ~/ _blockCols;
      final blockH = height ~/ _blockRows;
      if (blockW == 0 || blockH == 0) return null;

      final result = Uint8List(_blockCols * _blockRows);
      for (int by = 0; by < _blockRows; by++) {
        for (int bx = 0; bx < _blockCols; bx++) {
          int sum = 0;
          int count = 0;
          final startY = by * blockH;
          final endY = min(startY + blockH, height);
          final startX = bx * blockW;
          final endX = min(startX + blockW, width);

          for (int y = startY; y < endY; y++) {
            final rowStart = y * yPlane.stride + startX;
            int x = startX;
            while (x < endX) {
              final idx = rowStart + (x - startX);
              if (idx < yPlane.bytes.length) {
                sum += yPlane.bytes[idx];
                count++;
              }
              x++;
            }
          }
          result[by * _blockCols + bx] = (count > 0) ? (sum ~/ count) : 0;
        }
      }
      return result;
    } on Object {
      return null;
    }
  }

  int _compareGrids(Uint8List prev, Uint8List curr) {
    int changed = 0;
    final len = min(prev.length, curr.length);
    for (int i = 0; i < len; i++) {
      final diff = (prev[i] - curr[i]).abs();
      if (diff > _yDiffThreshold) changed++;
    }
    return changed;
  }

  Future<void> _runAnalysisTick() async {
    if (!_isActive || _disposed) return;
    // keep-alive / status heartbeat
    if (onStatusChanged != null) {
      final status = _lastDetectionTime != null &&
              DateTime.now().difference(_lastDetectionTime!).inSeconds < 10
          ? 'DETECTING'
          : 'SCANNING';
      onStatusChanged!(status);
    }
  }

  Future<void> _captureAndSend() async {
    if (!_isActive || _disposed) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final file = await controller.takePicture();
      if (_disposed) return;

      final bytes = await file.readAsBytes();
      if (_disposed || bytes.isEmpty) return;

      await _uploadToPushover(bytes);
    } on Object catch (e) {
      _reportError('Capture failed: $e');
    }
  }

  Future<void> _uploadToPushover(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_pushoverUrl),
      );
      request.fields['user'] = _settings.motionDetectUserKey;
      request.fields['token'] = _settings.motionDetectApiToken;
      request.fields['message'] =
          'Motion detected at ${DateTime.now().toLocal()}';
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachment',
          imageBytes,
          filename: 'motion_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 && onMotionDetected != null) {
        onMotionDetected!(imageBytes);
      } else if (response.statusCode != 200) {
        _reportError('Pushover rejected: ${response.statusCode}');
      }
    } on SocketException catch (_) {
      _reportError('No network for Pushover');
    } on HttpException catch (e) {
      _reportError('Pushover error: $e');
    } on Object catch (e) {
      _reportError('Pushover upload failed: $e');
    }
  }

  void _notifyStatus(String status) {
    onStatusChanged?.call(status);
  }

  void _reportError(String error) {
    onError?.call(error);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _cleanup();
  }
}
