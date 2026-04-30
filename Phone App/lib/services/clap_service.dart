// lib/services/clap_service.dart
import 'dart:async';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

typedef ClapCallback = void Function();
typedef DbCallback = void Function(double db);

class ClapService {
  final NoiseMeter _noiseMeter = NoiseMeter();
  StreamSubscription<NoiseReading>? _subscription;

  ClapCallback? onDoubleClap;
  DbCallback? onDbUpdate; // For intimacy mode

  // ── Clap detection state ──────────────────────────────
  final List<double> _recentDb = [];
  static const int _windowSize = 25;

  DateTime? _lastClapTime;
  int _clapCount = 0;
  Timer? _clapResetTimer;
  bool _inCooldown = false;

  double clapThreshold; // dB above rolling average = clap
  int clapWindowMs; // Double-clap time window

  bool _isRunning = false;

  ClapService({
    this.clapThreshold = 15.0,
    this.clapWindowMs = 1500,
  });

  bool get isRunning => _isRunning;

  Future<bool> start() async {
    if (_isRunning) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    try {
      _subscription = _noiseMeter.noise.listen(
        _onNoise,
        onError: (e) {
          _isRunning = false;
          // Auto-restart after error
          Future.delayed(const Duration(seconds: 2), start);
        },
        cancelOnError: false,
      );
      _isRunning = true;
      return true;
    } catch (e) {
      _isRunning = false;
      return false;
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
    _clapResetTimer?.cancel();
  }

  void _onNoise(NoiseReading reading) {
    final db = reading.maxDecibel;

    // Forward dB to intimacy mode listener
    onDbUpdate?.call(db);

    // Rolling average for adaptive threshold
    _recentDb.add(db);
    if (_recentDb.length > _windowSize) _recentDb.removeAt(0);

    if (_recentDb.length < 5) return; // Not enough data yet

    final avg = _recentDb.reduce((a, b) => a + b) / _recentDb.length;
    final spike = db - avg;

    // Clap = sharp spike above threshold, minimum 55 dB absolute
    if (spike >= clapThreshold && db > 55 && !_inCooldown) {
      _registerClap();
    }
  }

  void _registerClap() {
    _inCooldown = true;
    final now = DateTime.now();

    // Debounce: ignore if too close to last clap (< 200ms)
    if (_lastClapTime != null &&
        now.difference(_lastClapTime!).inMilliseconds < 200) {
      _releaseCooldown();
      return;
    }

    _lastClapTime = now;
    _clapCount++;

    if (_clapCount >= 2) {
      // Double clap detected!
      _clapCount = 0;
      _clapResetTimer?.cancel();
      _releaseCooldown();
      onDoubleClap?.call();
    } else {
      // Start window timer — if second clap doesn't come, reset
      _clapResetTimer?.cancel();
      _clapResetTimer = Timer(Duration(milliseconds: clapWindowMs), () {
        _clapCount = 0;
      });
      _releaseCooldown();
    }
  }

  void _releaseCooldown() {
    Future.delayed(const Duration(milliseconds: 150), () {
      _inCooldown = false;
    });
  }

  void dispose() {
    stop();
  }
}
