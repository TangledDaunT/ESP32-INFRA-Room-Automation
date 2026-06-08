// lib/providers/alarm_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import 'device_provider.dart';

/// Orchestrates alarm state for the UI.
///
/// - Bridges [AlarmService] → [DeviceProvider] when an alarm fires.
/// - When firing: turns on ESP32 LED strip + backup flashlight, plays sound.
/// - Exposes [isAlarmFiring] for overlay visibility.
/// - Exposes [firingAlarm] for display in the overlay.
class AlarmProvider extends ChangeNotifier {
  final AlarmService _alarmService;
  final DeviceProvider _deviceProvider;

  AlarmModel? _firingAlarm;
  bool _isAlarmFiring = false;

  Timer? _flashTimer;
  bool _flashState = false;

  AlarmProvider({
    required AlarmService alarmService,
    required DeviceProvider deviceProvider,
  })  : _alarmService = alarmService,
        _deviceProvider = deviceProvider {
    _alarmService.onAlarmFired = _onAlarmFired;
  }

  // ── Public state ───────────────────────────────────────────

  bool get isAlarmFiring => _isAlarmFiring;
  AlarmModel? get firingAlarm => _firingAlarm;
  List<AlarmModel> get alarms => _alarmService.alarms;

  // ── Alarm firing ───────────────────────────────────────────

  void _onAlarmFired(AlarmModel alarm) {
    _firingAlarm = alarm;
    _isAlarmFiring = true;

    // Turn on ESP32 LED strip (relay 2 = RGB) at full brightness
    _deviceProvider.setRgb(true);
    _deviceProvider.setRgbBrightness(255);

    // Initial flashlight turn on
    _flashState = true;
    _deviceProvider.setBackupBrightness(255);
    HapticFeedback.vibrate();

    // Flash the flashlight on and off repeatedly (every 500ms)
    _flashTimer?.cancel();
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _flashState = !_flashState;
      _deviceProvider.setBackupBrightness(_flashState ? 255 : 0);
      HapticFeedback.vibrate();
    });

    notifyListeners();
  }

  // ── Snooze ─────────────────────────────────────────────────

  void snooze() {
    if (_firingAlarm == null) return;
    final alarm = _firingAlarm!;

    // Stop hardware effects immediately
    _stopHardware();

    _isAlarmFiring = false;
    notifyListeners();

    // AlarmService will re-fire after 5 minutes
    _alarmService.snooze(alarm);
  }

  // ── Dismiss ────────────────────────────────────────────────

  void dismiss() {
    _stopHardware();
    _alarmService.dismiss();
    _isAlarmFiring = false;
    _firingAlarm = null;
    notifyListeners();
  }

  // ── Hardware teardown ──────────────────────────────────────

  void _stopHardware() {
    _flashTimer?.cancel();
    _flashTimer = null;
    // Turn off backup flashlight
    _deviceProvider.setBackupBrightness(0);
    // Leave RGB in whatever state it was before; user can control it manually.
    // If RGB was off before alarm, turn it off again.
    _deviceProvider.setRgb(false);
  }

  // ── Alarm CRUD (delegated to service) ─────────────────────

  Future<void> addAlarm(AlarmModel alarm) async {
    await _alarmService.addAlarm(alarm);
    notifyListeners();
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    await _alarmService.updateAlarm(alarm);
    notifyListeners();
  }

  Future<void> removeAlarm(String id) async {
    await _alarmService.removeAlarm(id);
    notifyListeners();
  }

  Future<void> toggleAlarm(String id) async {
    await _alarmService.toggleAlarm(id);
    notifyListeners();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }
}
