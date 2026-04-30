// lib/services/sleep_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/device_state.dart';

typedef SleepStateCallback = void Function(SleepState state);
// typedef VoidCallback = void Function();

class SleepService {
  AppSettings _settings;
  SleepStateCallback? onSleepStateChanged;
  VoidCallback? onTurnOffAll;
  VoidCallback? onTurnOnMainLight;
  VoidCallback? onAway;

  SleepState _currentState = SleepState.awake;
  Timer? _evaluationTimer;

  // Tracked values
  double _currentLux = 0;
  double _currentSmoke = 0;
  bool _currentPresence = false;
  bool _lightsOn = false;
  DateTime? _lightsOffAt;
  DateTime? _presenceLostAt;

  SleepService(this._settings);

  void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  void start() {
    _evaluationTimer?.cancel();
    // Evaluate every 60 seconds
    _evaluationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _evaluate();
    });
  }

  void stop() {
    _evaluationTimer?.cancel();
  }

  // Called by DeviceProvider when sensor values update
  void updateSensors({
    required double lux,
    required double smoke,
    required bool presence,
    required bool anyLightOn,
  }) {
    _currentLux = lux;
    _currentSmoke = smoke;

    // Presence tracking
    if (presence && !_currentPresence) {
      // Someone just entered
      _presenceLostAt = null;
      if (_currentState != SleepState.sleeping) {
        onTurnOnMainLight?.call();
      }
    } else if (!presence && _currentPresence) {
      // Presence just lost
      _presenceLostAt = DateTime.now();
    }
    _currentPresence = presence;

    // Light tracking
    if (!anyLightOn && _lightsOn) {
      _lightsOffAt = DateTime.now();
    } else if (anyLightOn) {
      _lightsOffAt = null;
    }
    _lightsOn = anyLightOn;

    _evaluate();
  }

  void _evaluate() {
    final now = DateTime.now();
    final isNight = _isNightTime(now);

    // ── Away detection ─────────────────────────────────
    if (_presenceLostAt != null && !_currentPresence) {
      final awayMinutes = now.difference(_presenceLostAt!).inMinutes;
      if (awayMinutes >= _settings.presenceAbsenceMinutes) {
        if (_currentState != SleepState.sleeping) {
          // Person left the room — turn off everything
          onAway?.call();
        }
      }
    }

    // ── Sleep detection ────────────────────────────────
    if (isNight && _currentPresence) {
      final lightsOffMinutes = _lightsOffAt != null
          ? now.difference(_lightsOffAt!).inMinutes
          : 0;

      // Conditions for sleeping:
      // 1. Lights have been off for sleepDetectionMinutes
      // 2. MQ2 elevated (person in room, breathing)
      // 3. Presence detected (person is there but still)
      // 4. It's night time or lux is low
      final smokElevated = _currentSmoke >= _settings.mq2SleepThreshold;
      final lightsOffLong = lightsOffMinutes >= _settings.sleepDetectionMinutes;
      final luxLow = _currentLux < _settings.luxNightThreshold;

      if (lightsOffLong && (smokElevated || luxLow)) {
        if (_currentState != SleepState.sleeping &&
            _currentState != SleepState.wakingUp) {
          _setState(SleepState.sleeping);
          onTurnOffAll?.call(); // Ensure everything is off
        }
      } else if (isNight && _currentState == SleepState.awake) {
        _setState(SleepState.nightMode);
      }
    } else if (!isNight && _currentState == SleepState.sleeping) {
      // Morning — don't auto-wake here, wakeup service handles it
    } else if (!isNight && _currentState == SleepState.nightMode) {
      _setState(SleepState.awake);
    }
  }

  bool _isNightTime(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final nightStartMinutes =
        _settings.nightStartHour * 60 + _settings.nightStartMinute;
    final nightEndMinutes =
        _settings.nightEndHour * 60 + _settings.nightEndMinute;

    // Also check lux
    final luxIsNight = _currentLux < _settings.luxNightThreshold && _currentLux > 0;

    // Night = (after nightStart OR before nightEnd) OR lux low
    bool timeNight;
    if (nightStartMinutes > nightEndMinutes) {
      // Wraps midnight (e.g. 22:00 → 06:00)
      timeNight = currentMinutes >= nightStartMinutes ||
          currentMinutes < nightEndMinutes;
    } else {
      timeNight = currentMinutes >= nightStartMinutes &&
          currentMinutes < nightEndMinutes;
    }

    return timeNight || luxIsNight;
  }

  void _setState(SleepState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    onSleepStateChanged?.call(newState);
  }

  SleepState get currentState => _currentState;

  void forceState(SleepState state) => _setState(state);

  bool get isNightNow => _isNightTime(DateTime.now());

  void dispose() {
    stop();
  }
}
