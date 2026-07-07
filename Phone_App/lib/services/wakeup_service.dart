// lib/services/wakeup_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';

typedef BrightnessCallback = void Function(int brightness);
// typedef VoidCallback = void Function();

class WakeupService {
  AppSettings _settings;

  BrightnessCallback? onRgbBrightness; // Set RGB brightness during ramp
  VoidCallback? onRgbOn; // Turn on RGB
  VoidCallback? onLightOn; // Turn on main light at wake time
  VoidCallback? onWakeupComplete; // Notify OpenClaw
  VoidCallback? onRampStarted; // Let SleepService know a ramp is in progress

  Timer? _checkTimer;
  Timer? _rampTimer;
  bool _rampStarted = false;
  bool _wakeupFired = false;

  WakeupService(this._settings);

  void updateSettings(AppSettings settings) {
    _settings = settings;
    // Restart to pick up new wake time
    if (_checkTimer != null) {
      stop();
      start();
    }
  }

  void start() {
    _checkTimer?.cancel();
    // Check every minute if it's ramp or wake time
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    _check(); // Run immediately too
  }

  void stop() {
    _checkTimer?.cancel();
    _rampTimer?.cancel();
    _rampStarted = false;
    _wakeupFired = false;
  }

  /// Minutes a scheduled event tolerates being late by before giving up —
  /// covers a single missed `_checkTimer` tick (e.g. under Android Doze)
  /// without risking firing hours late if the app was genuinely suspended.
  static const int _graceMinutes = 5;

  void _check() {
    final now = DateTime.now();
    final wakeMinutes = _settings.wakeUpHour * 60 + _settings.wakeUpMinute;
    final currentMinutes = now.hour * 60 + now.minute;
    final rampStartMinutes = wakeMinutes - _settings.wakeUpRampMinutes;

    // Reset flags at noon (so it can fire again tomorrow)
    if (now.hour == 12 && now.minute == 0) {
      _rampStarted = false;
      _wakeupFired = false;
    }

    // Start ramp X minutes before wake time (tolerates a missed tick)
    if (!_rampStarted && _withinGrace(currentMinutes, rampStartMinutes)) {
      _startRamp();
    }

    // Fire wake-up at/just after the exact time (tolerates a missed tick)
    if (!_wakeupFired && _withinGrace(currentMinutes, wakeMinutes)) {
      _fireWakeup();
    }
  }

  bool _withinGrace(int currentMinutes, int targetMinutes) {
    final diff = currentMinutes - targetMinutes;
    return diff >= 0 && diff <= _graceMinutes;
  }

  void _startRamp() {
    _rampStarted = true;
    _rampTimer?.cancel();

    onRgbOn?.call();
    onRgbBrightness?.call(0);

    // Ramp from 0 → 128 over rampMinutes
    // Tick every 30 seconds = rampMinutes * 2 ticks total
    final totalTicks = _settings.wakeUpRampMinutes * 2;
    int tick = 0;
    const int targetBrightness = 128; // 50%

    _rampTimer = Timer.periodic(const Duration(seconds: 30), (t) {
      tick++;
      final brightness = ((tick / totalTicks) * targetBrightness)
          .round()
          .clamp(0, targetBrightness);
      onRgbBrightness?.call(brightness);

      if (tick >= totalTicks) {
        t.cancel();
      }
    });
  }

  void _fireWakeup() {
    _wakeupFired = true;
    _rampTimer?.cancel();

    // Full brightness RGB + main light on
    onRgbBrightness?.call(255);
    onLightOn?.call();

    // Notify OpenClaw that wake-up routine is done
    onWakeupComplete?.call();
  }

  /// Manually trigger a test wake-up ramp (for settings preview)
  void testRamp({int durationSeconds = 10}) {
    _rampTimer?.cancel();
    onRgbOn?.call();
    onRgbBrightness?.call(0);

    int tick = 0;
    final totalTicks = durationSeconds;

    _rampTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      tick++;
      final brightness = ((tick / totalTicks) * 255).round().clamp(0, 255);
      onRgbBrightness?.call(brightness);
      if (tick >= totalTicks) t.cancel();
    });
  }

  void dispose() {
    stop();
  }
}
