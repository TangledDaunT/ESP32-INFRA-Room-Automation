// lib/services/openclaw_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/device_state.dart';

typedef StateCallback = void Function(Map<String, dynamic> state);
// typedef VoidCallback = void Function();

class OpenClawService {
  AppSettings _settings;
  StateCallback? onStateReceived;

  Timer? _pollTimer;
  bool _polling = false;

  OpenClawService(this._settings);

  void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  String get _base => _settings.openclawBaseUrl;

  Future<bool> checkConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getState() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/state'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> setDevice(String device, bool state) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/control/$device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'state': state ? 'ON' : 'OFF'}),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBrightness(String device, int brightness) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/control/$device/brightness'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'brightness': brightness}),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> notifyWakeupDone() async {
    try {
      final res = await http.post(
        Uri.parse('$_base/wakeup/done'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Wake-up routine complete from OpenClaw Remote',
        }),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> notifySleepState(SleepState state) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/sleep/state'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'state': state.name}),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncWakeUpTime(int hour, int minute) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/settings/wakeup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'hour': hour, 'minute': minute}),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Poll state from OpenClaw every N seconds for bidirectional sync
  void startPolling({int intervalSeconds = 3}) {
    _pollTimer?.cancel();
    _polling = true;
    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        if (!_polling) return;
        final state = await getState();
        if (state != null) onStateReceived?.call(state);
      },
    );
  }

  void stopPolling() {
    _polling = false;
    _pollTimer?.cancel();
  }

  void dispose() {
    stopPolling();
  }
}
