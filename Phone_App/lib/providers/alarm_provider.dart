// lib/providers/alarm_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/alarm_model.dart';
import '../services/activity_log_service.dart';
import '../services/alarm_service.dart';
import 'device_provider.dart';

/// Orchestrates alarm state for the UI.
///
/// - Bridges [AlarmService] → [DeviceProvider] when an alarm fires.
/// - When firing: turns on ESP32 LED strip + backup flashlight once, plays
///   sound. The actual "flashing" look is a purely local animation in
///   [AlarmOverlay] (its pulsing glow + expanding ring) — earlier this
///   toggled the ESP32 relays on/off over HTTP every 300-500ms for the
///   entire duration of an unacknowledged alarm, which is unnecessary
///   network load for a visual effect the overlay already renders locally.
/// - Exposes [isAlarmFiring] for overlay visibility.
/// - Exposes [firingAlarm] for display in the overlay.
class AlarmProvider extends ChangeNotifier {
  final AlarmService _alarmService;
  final DeviceProvider _deviceProvider;
  final ActivityLogService _activityLog;

  AlarmModel? _firingAlarm;
  bool _isAlarmFiring = false;

  AlarmProvider({
    required AlarmService alarmService,
    required DeviceProvider deviceProvider,
    required ActivityLogService activityLog,
  })  : _alarmService = alarmService,
        _deviceProvider = deviceProvider,
        _activityLog = activityLog {
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

    if (alarm.kind == AlarmKind.smoke) {
      _activityLog.addAlarm('Smoke alarm', alarm.label.isEmpty ? 'Smoke threshold crossed' : alarm.label);
      _alarmService.startAudioLoop();
      _activateSmokeLighting();
    } else {
      _activityLog.addAlarm('Scheduled alarm', alarm.label.isEmpty ? alarm.timeString : alarm.label);

      // Turn on ESP32 LED strip (relay 2 = RGB) and backup flashlight at
      // full brightness once — the flashing look itself is rendered
      // locally by AlarmOverlay's pulse/ring animation, not by toggling
      // the relays repeatedly.
      _deviceProvider.setRgb(true);
      _deviceProvider.setRgbBrightness(255);
      _deviceProvider.setBackupBrightness(255);
      HapticFeedback.vibrate();
    }

    notifyListeners();
  }

  void triggerSmokeAlarm({String label = 'SMOKE ALARM'}) {
    _firingAlarm = AlarmModel(
      id: 'smoke-${DateTime.now().millisecondsSinceEpoch}',
      hour: DateTime.now().hour,
      minute: DateTime.now().minute,
      label: label,
      isEnabled: true,
      kind: AlarmKind.smoke,
    );
    _isAlarmFiring = true;
    _activityLog.addSystem('Smoke alarm triggered', label);
    _alarmService.startAudioLoop();
    _activateSmokeLighting();
    notifyListeners();
  }

  void _activateSmokeLighting() {
    _deviceProvider.setBackupBrightness(0);
    _deviceProvider.setRgb(true);
    _deviceProvider.setRgbBrightness(255);
    HapticFeedback.vibrate();
  }

  // ── Snooze ─────────────────────────────────────────────────

  void snooze() {
    if (_firingAlarm == null) return;
    final alarm = _firingAlarm!;

    if (alarm.kind == AlarmKind.smoke) {
      dismiss();
      return;
    }

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
    _activityLog.addSystem('Alarm dismissed', _firingAlarm?.label ?? '');
    _isAlarmFiring = false;
    _firingAlarm = null;
    notifyListeners();
  }

  // ── Hardware teardown ──────────────────────────────────────

  void _stopHardware() {
    // Turn off backup flashlight
    _deviceProvider.setBackupBrightness(0);
    _deviceProvider.setRgbBrightness(0);
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
    // Avoid a stale callback firing into this disposed ChangeNotifier.
    _alarmService.onAlarmFired = null;
    super.dispose();
  }
}
