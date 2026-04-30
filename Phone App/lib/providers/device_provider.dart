// lib/providers/device_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';
import '../services/openclaw_service.dart';
import '../services/clap_service.dart';
import '../services/sleep_service.dart';
import '../services/wakeup_service.dart';
import '../services/ble_service.dart';

class DeviceProvider extends ChangeNotifier {
  late final MqttService _mqtt;
  late final OpenClawService _openclaw;
  late final ClapService _clap;
  late final SleepService _sleep;
  late final WakeupService _wakeup;
  late final BleService _ble;

  DeviceState _state = DeviceState();
  AppSettings _settings;

  // Intimacy mode
  bool _intimacyMode = false;
  Timer? _intimacyTimer;
  double _smoothedDb = 50.0;
  static const double _intimacySmoothing = 0.3;

  // PWM ramp for clap-triggered RGB
  Timer? _rampTimer;

  DeviceProvider(this._settings) {
    _mqtt = MqttService(_settings);
    _openclaw = OpenClawService(_settings);
    _clap = ClapService(
      clapThreshold: _settings.clapDbThreshold,
      clapWindowMs: _settings.clapWindowMs,
    );
    _sleep = SleepService(_settings);
    _wakeup = WakeupService(_settings);
    _ble = BleService(_settings.bleDeviceName);

    _setupCallbacks();
    _init();
  }

  DeviceState get state => _state;
  bool get intimacyMode => _intimacyMode;
  AppSettings get settings => _settings;

  void _setupCallbacks() {
    // ── MQTT ──────────────────────────────────────────
    _mqtt.onMessage = _onMqttMessage;
    _mqtt.onConnected = () {
      _updateState(_state.copyWith(mqttStatus: ConnectionStatus.connected));
    };
    _mqtt.onDisconnected = () {
      _updateState(_state.copyWith(mqttStatus: ConnectionStatus.disconnected));
    };

    // ── OpenClaw state sync ────────────────────────────
    _openclaw.onStateReceived = _onOpenClawState;

    // ── Clap detection ────────────────────────────────
    _clap.onDoubleClap = _handleDoubleClap;
    _clap.onDbUpdate = _onDbUpdate;

    // ── Sleep service ─────────────────────────────────
    _sleep.onSleepStateChanged = (state) {
      _updateState(_state.copyWith(
        sleepState: state,
        isNightMode: state == SleepState.nightMode ||
            state == SleepState.sleeping ||
            state == SleepState.possiblySleeping,
      ));
      _openclaw.notifySleepState(state);
      if (state == SleepState.nightMode) _applyNightMode();
    };
    _sleep.onTurnOffAll = _turnOffAll;
    _sleep.onTurnOnMainLight = () => setLight(true);
    _sleep.onAway = _onAway;

    // ── Wake-up service ───────────────────────────────
    _wakeup.onRgbOn = () => setRgb(true);
    _wakeup.onRgbBrightness = (b) => setRgbBrightness(b);
    _wakeup.onLightOn = () => setLight(true);
    _wakeup.onWakeupComplete = () {
      _mqtt.publishJson(_settings.topicWakeupDone, {
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Wake-up complete — check if I am awake',
      });
      _openclaw.notifyWakeupDone();
      _sleep.forceState(SleepState.awake);
    };

    // ── BLE ───────────────────────────────────────────
    _ble.onSensorData = _onBleSensorData;
    _ble.onStatusChanged = (status) {
      _updateState(_state.copyWith(bleStatus: status));
    };
  }

  Future<void> _init() async {
    // Connect MQTT
    _updateState(_state.copyWith(mqttStatus: ConnectionStatus.connecting));
    await _mqtt.connect();

    // Check OpenClaw
    final ok = await _openclaw.checkConnection();
    _updateState(_state.copyWith(
      openclawStatus:
          ok ? ConnectionStatus.connected : ConnectionStatus.disconnected,
    ));
    if (ok) {
      _openclaw.startPolling();
      // Sync wake-up time to OpenClaw
      _openclaw.syncWakeUpTime(_settings.wakeUpHour, _settings.wakeUpMinute);
    }

    // Start BLE scan
    _ble.startScan();

    // Start clap detection (always on)
    await _clap.start();

    // Start sleep service
    _sleep.start();

    // Start wake-up scheduler
    _wakeup.start();
  }

  // ── Device Control ────────────────────────────────────

  void setFan(bool on) {
    _updateState(_state.copyWith(fanOn: on));
    _mqtt.publishDeviceCommand(_settings.topicFan, on);
    _ble.sendCommand({'device': 'fan', 'state': on ? 'ON' : 'OFF'});
    _notifyActivity();
  }

  void setLight(bool on) {
    _updateState(_state.copyWith(lightOn: on));
    _mqtt.publishDeviceCommand(_settings.topicLight, on);
    _ble.sendCommand({'device': 'light', 'state': on ? 'ON' : 'OFF'});
    _notifyActivity();
  }

  void setSocket(bool on) {
    _updateState(_state.copyWith(socketOn: on));
    _mqtt.publishDeviceCommand(_settings.topicSocket, on);
    _ble.sendCommand({'device': 'socket', 'state': on ? 'ON' : 'OFF'});
    _notifyActivity();
  }

  void setRgb(bool on) {
    _updateState(_state.copyWith(rgbOn: on));
    _mqtt.publishDeviceCommand(_settings.topicRgb, on);
    _ble.sendCommand({'device': 'rgb', 'state': on ? 'ON' : 'OFF'});
    _notifyActivity();
  }

  void setRgbBrightness(int brightness) {
    _updateState(_state.copyWith(rgbBrightness: brightness));
    _mqtt.publishBrightness(_settings.topicRgbBrightness, brightness);
    _ble.sendCommand({'device': 'rgb', 'brightness': brightness});
  }

  void setBackupBrightness(int brightness) {
    _updateState(_state.copyWith(backupBrightness: brightness));
    _mqtt.publishBrightness(_settings.topicBackupBrightness, brightness);
    _ble.sendCommand({'device': 'backup', 'brightness': brightness});
    _notifyActivity();
  }

  void _notifyActivity() {
    _updateState(_state.copyWith(lastActivityTime: DateTime.now()));
    // Track lights-off for sleep detection
    _sleep.updateSensors(
      lux: _state.luxValue,
      smoke: _state.smokeValue,
      presence: _state.presenceDetected,
      anyLightOn: _state.anyLightOn,
    );
  }

  // ── MQTT Incoming ─────────────────────────────────────

  void _onMqttMessage(String topic, String payload) {
    final s = _settings;

    if (topic == s.topicFan) {
      _updateState(_state.copyWith(fanOn: payload.toUpperCase() == 'ON'));
    } else if (topic == s.topicLight) {
      _updateState(_state.copyWith(lightOn: payload.toUpperCase() == 'ON'));
    } else if (topic == s.topicSocket) {
      _updateState(_state.copyWith(socketOn: payload.toUpperCase() == 'ON'));
    } else if (topic == s.topicRgb) {
      _updateState(_state.copyWith(rgbOn: payload.toUpperCase() == 'ON'));
    } else if (topic == s.topicRgbBrightness) {
      final b = int.tryParse(payload);
      if (b != null) {
        _updateState(_state.copyWith(rgbBrightness: b.clamp(0, 255)));
      }
    } else if (topic == s.topicBackupBrightness) {
      final b = int.tryParse(payload);
      if (b != null) {
        _updateState(_state.copyWith(backupBrightness: b.clamp(0, 255)));
      }
    } else if (topic == s.topicSmoke) {
      final v = double.tryParse(payload);
      if (v != null) {
        final alarm = v >= s.smokeAlarmThreshold;
        _updateState(_state.copyWith(smokeValue: v, smokeAlarm: alarm));
        _checkSleepConditions();
      }
    } else if (topic == s.topicLux) {
      final v = double.tryParse(payload);
      if (v != null) {
        _updateState(_state.copyWith(luxValue: v));
        _checkSleepConditions();
      }
    } else if (topic == s.topicPresence) {
      final present = payload.toUpperCase() == 'PRESENT' ||
          payload == '1' ||
          payload == 'true';
      _updateState(_state.copyWith(presenceDetected: present));
      _checkSleepConditions();
    } else if (topic == s.topicStateSync) {
      _parseFullState(payload);
    }
  }

  void _onOpenClawState(Map<String, dynamic> data) {
    // Sync state from OpenClaw (bidirectional)
    _parseFullState(jsonEncode(data));
  }

  void _parseFullState(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _updateState(_state.copyWith(
        fanOn: data['fan'] == 'ON' || data['fan'] == true,
        lightOn: data['light'] == 'ON' || data['light'] == true,
        socketOn: data['socket'] == 'ON' || data['socket'] == true,
        rgbOn: data['rgb'] == 'ON' || data['rgb'] == true,
        rgbBrightness: data['rgb_brightness'] ?? _state.rgbBrightness,
        backupBrightness: data['backup_brightness'] ?? _state.backupBrightness,
        smokeValue: (data['smoke'] ?? _state.smokeValue).toDouble(),
        luxValue: (data['lux'] ?? _state.luxValue).toDouble(),
        presenceDetected:
            data['presence'] == true || data['presence'] == 'PRESENT',
      ));
    } catch (_) {}
  }

  void _onBleSensorData(Map<String, dynamic> data) {
    // BLE sensor updates (real-time from ESP32 directly)
    if (data.containsKey('smoke')) {
      final v = (data['smoke'] as num).toDouble();
      _updateState(_state.copyWith(
        smokeValue: v,
        smokeAlarm: v >= _settings.smokeAlarmThreshold,
      ));
    }
    if (data.containsKey('lux')) {
      _updateState(_state.copyWith(luxValue: (data['lux'] as num).toDouble()));
    }
    if (data.containsKey('presence')) {
      _updateState(_state.copyWith(presenceDetected: data['presence'] == true));
    }
    _checkSleepConditions();
  }

  void _checkSleepConditions() {
    _sleep.updateSensors(
      lux: _state.luxValue,
      smoke: _state.smokeValue,
      presence: _state.presenceDetected,
      anyLightOn: _state.anyLightOn,
    );
  }

  // ── Clap Automation ───────────────────────────────────

  void _handleDoubleClap() {
    final isNight = _sleep.isNightNow;

    if (isNight) {
      // Night behavior
      if (_state.anyLightOn) {
        // Lights are on → turn them all off slowly (RGB fade then main off)
        _slowFadeRgb(
            target: 0,
            onComplete: () {
              setRgb(false);
              setLight(false);
            });
      } else {
        // Lights are off → slowly turn on RGB strip only to 50%
        setRgb(true);
        _slowRampRgb(from: 0, to: 128, durationMs: 3000);
      }
    } else {
      // Day behavior
      if (_state.rgbOn && _state.rgbBrightness > 0) {
        // RGB is on → turn it off
        _slowFadeRgb(target: 0, onComplete: () => setRgb(false));
      } else {
        // RGB is off → slowly turn it on to full
        setRgb(true);
        _slowRampRgb(from: 0, to: 255, durationMs: 3000);
      }
    }
  }

  void _slowRampRgb({
    required int from,
    required int to,
    required int durationMs,
    VoidCallback? onComplete,
  }) {
    _rampTimer?.cancel();
    const int steps = 30;
    final int stepMs = durationMs ~/ steps;
    int step = 0;

    setRgbBrightness(from);

    _rampTimer = Timer.periodic(Duration(milliseconds: stepMs), (t) {
      step++;
      final brightness =
          (from + ((to - from) * (step / steps))).round().clamp(0, 255);
      setRgbBrightness(brightness);
      if (step >= steps) {
        t.cancel();
        onComplete?.call();
      }
    });
  }

  void _slowFadeRgb({required int target, VoidCallback? onComplete}) {
    _slowRampRgb(
      from: _state.rgbBrightness,
      to: target,
      durationMs: 2000,
      onComplete: onComplete,
    );
  }

  // ── Night Mode Auto ───────────────────────────────────

  void _applyNightMode() {
    // Turn off main light, set RGB to 50%
    setLight(false);
    if (_state.rgbOn) {
      setRgbBrightness(128);
    }
  }

  void _turnOffAll() {
    setFan(false);
    setLight(false);
    setSocket(false);
    setRgb(false);
    setBackupBrightness(0);
  }

  void _onAway() {
    _turnOffAll();
  }

  // ── Intimacy Mode ─────────────────────────────────────

  void _onDbUpdate(double db) {
    if (!_intimacyMode) return;

    // Exponential moving average for smooth response
    _smoothedDb =
        _smoothedDb * (1 - _intimacySmoothing) + db * _intimacySmoothing;

    // Map 40dB (quiet) → 90dB (loud) to brightness 20 → 255
    const double minDb = 40.0;
    const double maxDb = 90.0;
    final normalized =
        ((_smoothedDb - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    final brightness = (normalized * 235 + 20).round().clamp(20, 255);

    setRgbBrightness(brightness);
  }

  void toggleIntimacyMode() {
    _intimacyMode = !_intimacyMode;
    _updateState(_state.copyWith(intimacyMode: _intimacyMode));

    if (_intimacyMode) {
      setRgb(true);
    }
    notifyListeners();
  }

  // ── Settings Update ───────────────────────────────────

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    _mqtt.updateSettings(settings);
    _openclaw.updateSettings(settings);
    _sleep.updateSettings(settings);
    _wakeup.updateSettings(settings);
    _ble.deviceName = settings.bleDeviceName;
    _clap.clapThreshold = settings.clapDbThreshold;
    _clap.clapWindowMs = settings.clapWindowMs;

    // Sync wake-up time to OpenClaw
    _openclaw.syncWakeUpTime(settings.wakeUpHour, settings.wakeUpMinute);

    notifyListeners();
  }

  // ── Reconnect / Retry ─────────────────────────────────

  Future<void> reconnectMqtt() async {
    _mqtt.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await _mqtt.connect();
  }

  Future<void> reconnectBle() async {
    _ble.disconnect();
    await Future.delayed(const Duration(milliseconds: 1000));
    _ble.startScan();
  }

  void _updateState(DeviceState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _mqtt.dispose();
    _openclaw.dispose();
    _clap.dispose();
    _sleep.dispose();
    _wakeup.dispose();
    _ble.dispose();
    _rampTimer?.cancel();
    _intimacyTimer?.cancel();
    super.dispose();
  }
}
