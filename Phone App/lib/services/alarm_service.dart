// lib/services/alarm_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/alarm_model.dart';

typedef AlarmFiredCallback = void Function(AlarmModel alarm);

/// Manages alarm scheduling, persistence, and audio playback.
///
/// - Polls every 30 seconds to check if an alarm should fire.
/// - Persists alarms to SharedPreferences as a JSON list.
/// - Plays the bundled beep sound on loop when an alarm fires.
/// - Supports snooze (5 minutes) and dismiss.
class AlarmService {
  AlarmFiredCallback? onAlarmFired;

  final List<AlarmModel> _alarms = [];
  Timer? _checkTimer;
  Timer? _snoozeTimer;

  // Audio playback
  final AudioPlayer _player = AudioPlayer();
  bool _isFiring = false;

  // Track last-fired alarm id + minute to prevent re-firing same minute
  String? _lastFiredId;
  int? _lastFiredMinute; // encoded as hour*60+minute

  List<AlarmModel> get alarms => List.unmodifiable(_alarms);
  bool get isFiring => _isFiring;

  // ── Lifecycle ──────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AlarmModel.prefsKey);
    if (json != null) {
      try {
        final loaded = AlarmModel.decodeList(json);
        _alarms
          ..clear()
          ..addAll(loaded);
      } catch (e) {
        debugPrint('[AlarmService] Failed to load alarms: $e');
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AlarmModel.prefsKey, AlarmModel.encodeList(_alarms));
  }

  void start() {
    _checkTimer?.cancel();
    // Check every 30 seconds for alarm time matches
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _check(); // immediate check on start
  }

  void stop() {
    _checkTimer?.cancel();
    _snoozeTimer?.cancel();
  }

  void dispose() {
    stop();
    _player.dispose();
  }

  // ── CRUD ───────────────────────────────────────────────────

  Future<void> addAlarm(AlarmModel alarm) async {
    _alarms.add(alarm);
    await _persist();
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    final idx = _alarms.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      _alarms[idx] = alarm;
      await _persist();
    }
  }

  Future<void> removeAlarm(String id) async {
    _alarms.removeWhere((a) => a.id == id);
    await _persist();
  }

  Future<void> toggleAlarm(String id) async {
    final idx = _alarms.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      _alarms[idx] = _alarms[idx].copyWith(isEnabled: !_alarms[idx].isEnabled);
      await _persist();
    }
  }

  // ── Alarm checking ─────────────────────────────────────────

  void _check() {
    final now = DateTime.now();
    final nowEncoded = now.hour * 60 + now.minute;

    for (final alarm in _alarms) {
      if (!alarm.isEnabled) continue;
      final alarmEncoded = alarm.hour * 60 + alarm.minute;

      // Fire if: same minute AND not already fired this minute for this alarm
      if (alarmEncoded == nowEncoded &&
          (_lastFiredId != alarm.id || _lastFiredMinute != nowEncoded)) {
        _lastFiredId = alarm.id;
        _lastFiredMinute = nowEncoded;
        _fire(alarm);
        break; // Only fire one alarm at a time
      }
    }

    // Reset last-fired tracker when minute changes
    if (_lastFiredMinute != null && _lastFiredMinute != nowEncoded) {
      _lastFiredId = null;
      _lastFiredMinute = null;
    }
  }

  void _fire(AlarmModel alarm) {
    _isFiring = true;
    _startAudio();
    onAlarmFired?.call(alarm);
  }

  // ── Snooze / Dismiss ───────────────────────────────────────

  void snooze(AlarmModel alarm) {
    _stopAudio();
    _isFiring = false;
    _snoozeTimer?.cancel();
    _snoozeTimer = Timer(const Duration(minutes: 5), () {
      _fire(alarm);
    });
  }

  void dismiss() {
    _stopAudio();
    _isFiring = false;
    _snoozeTimer?.cancel();
  }

  // ── Audio ──────────────────────────────────────────────────

  void _startAudio() {
    _player.setReleaseMode(ReleaseMode.loop);
    _player.setVolume(1.0);
    _player.play(AssetSource('audio/alarm_beep.wav'));
  }

  void _stopAudio() {
    _player.stop();
  }
}
