// lib/providers/device_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/device_state.dart';
import '../services/openclaw_service.dart';
import '../services/clap_detector.dart';
import '../services/sleep_service.dart';
import '../services/wakeup_service.dart';

class DeviceProvider extends ChangeNotifier {
  late final OpenClawService _openclaw;
  late final ClapDetector _clap;
  late final SleepService _sleep;
  late final WakeupService _wakeup;

  DeviceState _state = DeviceState();
  AppSettings _settings;

  // Music mode
  bool _musicMode = false;
  Timer? _musicTimer;
  double _smoothedDb = 50.0;
  static const double _musicSmoothing = 0.3;

  // PWM ramp for clap-triggered RGB
  Timer? _rampTimer;
  Timer? _clapIndicatorTimer;
  bool _showClapIndicator = false;

  DeviceProvider(this._settings) {
    _openclaw = OpenClawService(_settings);
    _clap = ClapDetector(
      clapDbThreshold: _settings.clapDbThreshold,
      clapWindowMs: _settings.clapWindowMs,
    );
    _sleep = SleepService(_settings);
    _wakeup = WakeupService(_settings);

    _setupCallbacks();
    _init();
  }

  DeviceState get state => _state;
  bool get musicMode => _musicMode;
  bool get showClapIndicator => _showClapIndicator;
  AppSettings get settings => _settings;

  void _setupCallbacks() {
    // ── OpenClaw state sync ────────────────────────────
    _openclaw.onStateReceived = _onOpenClawState;
    _openclaw.onConnected = () {
      _updateState(_state.copyWith(openclawStatus: ConnectionStatus.connected));
    };
    _openclaw.onDisconnected = () {
      _updateState(_state.copyWith(openclawStatus: ConnectionStatus.disconnected));
    };

    // ── Clap detection ────────────────────────────────
    _clap.onDoubleClap = _handleDoubleClap;
    _clap.onSingleClap = _onSingleClap;
    _clap.onDbUpdate = _onDbUpdate;

    // ── Sleep service ─────────────────────────────────
    _sleep.onSleepStateChanged = (state) {
      _updateState(_state.copyWith(
        sleepState: state,
        isNightMode: state == SleepState.nightMode ||
            state == SleepState.sleeping ||
            state == SleepState.possiblySleeping,
      ));
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
      _sleep.forceState(SleepState.awake);
    };
  }

  Future<void> _init() async {
    // Connect WebSocket
    _openclaw.connect();

    // Start clap detection (always on)
    await _clap.start();

    // Start sleep service
    _sleep.start();

    // Start wake-up scheduler
    _wakeup.start();
  }

  // ── Device Control ────────────────────────────────────

  void setFan(bool on) {
    if (_state.fanOn == on) return;
    _updateState(_state.copyWith(fanOn: on));
    _openclaw.setRelay(1, on); // channel 1 = Fan
    _notifyActivity();
  }

  void setLight(bool on) {
    if (_state.lightOn == on) return;
    _updateState(_state.copyWith(lightOn: on));
    _openclaw.setRelay(0, on); // channel 0 = Light
    _notifyActivity();
  }

  void setSocket(bool on) {
    if (_state.socketOn == on) return;
    _updateState(_state.copyWith(socketOn: on));
    _openclaw.setRelay(3, on); // channel 3 = Socket
    _notifyActivity();
  }

  void setRgb(bool on) {
    if (_state.rgbOn == on) return;
    _updateState(_state.copyWith(rgbOn: on));
    _openclaw.setRelay(2, on); // channel 2 = RGB
    _notifyActivity();
  }

  void setRgbBrightness(int brightness) {
    if (_state.rgbBrightness == brightness) return;
    _updateState(_state.copyWith(rgbBrightness: brightness));
    _openclaw.setStripBrightness(brightness);
  }

  void setRgbBrightnessFast(int brightness, {int? duration}) {
    if (_state.rgbBrightness == brightness) return;
    _state = _state.copyWith(rgbBrightness: brightness);
    // Note: Do not call notifyListeners() here to avoid rebuilding UI 15+ times a second!

    final payload = <String, dynamic>{
      'device': 'rgb',
      'brightness': brightness,
    };
    if (duration != null) {
      payload['duration'] = duration;
    }
    _openclaw.sendWsCommand(payload);
  }

  void setBackupBrightness(int brightness) {
    if (_state.backupBrightness == brightness) return;
    _updateState(_state.copyWith(backupBrightness: brightness));
    _openclaw.setFlashBrightness(brightness);
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

  // ── WebSocket Incoming ─────────────────────────────────────

  void _onOpenClawState(Map<String, dynamic> data) {
    // The firmware /api/state JSON uses relay array + different key names:
    //   relays:[r0(light), r1(fan), r2(rgb), r3(socket)]
    //   flash = backup brightness, strip = rgb brightness
    //   present = presence (bool), lux, smoke

    final normalised = <String, dynamic>{};

    if (data.containsKey('relays') && data['relays'] is List) {
      final relays = data['relays'] as List;
      if (relays.length >= 4) {
        normalised['light']  = relays[0] == true;
        normalised['fan']    = relays[1] == true;
        normalised['rgb']    = relays[2] == true;
        normalised['socket'] = relays[3] == true;
      }
    }

    if (data.containsKey('strip')) {
      normalised['rgb_brightness'] = data['strip'];
    }
    if (data.containsKey('flash')) {
      normalised['backup_brightness'] = data['flash'];
    }
    if (data.containsKey('present')) {
      normalised['presence'] = data['present'];
    }
    if (data.containsKey('smoke')) normalised['smoke'] = data['smoke'];
    if (data.containsKey('lux'))   normalised['lux']   = data['lux'];

    _parseFullState(normalised);
  }

  void _parseFullState(Map<String, dynamic> data) {
    _updateState(_state.copyWith(
      fanOn: data['fan'] ?? _state.fanOn,
      lightOn: data['light'] ?? _state.lightOn,
      socketOn: data['socket'] ?? _state.socketOn,
      rgbOn: data['rgb'] ?? _state.rgbOn,
      rgbBrightness: data['rgb_brightness'] ?? _state.rgbBrightness,
      backupBrightness: data['backup_brightness'] ?? _state.backupBrightness,
      smokeValue: (data['smoke'] ?? _state.smokeValue).toDouble(),
      luxValue: (data['lux'] ?? _state.luxValue).toDouble(),
      presenceDetected: data['presence'] ?? _state.presenceDetected,
      smokeAlarm: (data['smoke'] ?? 0) >= _settings.smokeAlarmThreshold,
    ));

    // Update sleep service with new sensor data
    _sleep.updateSensors(
      lux: _state.luxValue,
      smoke: _state.smokeValue,
      presence: _state.presenceDetected,
      anyLightOn: _state.anyLightOn,
    );
  }

  // ── Clap Automation ───────────────────────────────────

  void _onSingleClap() {
    _clapIndicatorTimer?.cancel();
    _showClapIndicator = true;
    notifyListeners();

    _clapIndicatorTimer = Timer(const Duration(milliseconds: 400), () {
      _showClapIndicator = false;
      notifyListeners();
    });
  }

  void _handleDoubleClap() {
    // Turn on everything
    setFan(true);
    setLight(true);
    setSocket(true);
    setRgb(true);
    
    // Ramp RGB to full brightness if it isn't already
    if (_state.rgbBrightness < 255) {
      _slowRampRgb(from: _state.rgbBrightness, to: 255, durationMs: 1500);
    }
  }

  // Helper for testing double clap behavior on simulator where mic is unavailable
  void simulateDoubleClap() {
    _handleDoubleClap();
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

  // ── Music Mode ─────────────────────────────────────

  void _onDbUpdate(double db) {
    if (!_musicMode) return;

    // Exponential moving average for smooth response
    _smoothedDb =
        _smoothedDb * (1 - _musicSmoothing) + db * _musicSmoothing;

    // Map 40dB (quiet) → 90dB (loud) to brightness 20 → 255
    const double minDb = 40.0;
    const double maxDb = 90.0;
    final normalized =
        ((_smoothedDb - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    final brightness = (normalized * 235 + 20).round().clamp(20, 255);

    setRgbBrightnessFast(brightness, duration: 100);
  }

  void toggleMusicMode() {
    _musicMode = !_musicMode;
    _updateState(_state.copyWith(musicMode: _musicMode));

    if (_musicMode) {
      setRgb(true);
    }
    notifyListeners();
  }

  // ── Settings Update ───────────────────────────────────

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    _openclaw.updateSettings(settings);
    _sleep.updateSettings(settings);
    _wakeup.updateSettings(settings);
    _clap.updateSettings(settings.clapDbThreshold);

    notifyListeners();
  }

  void _updateState(DeviceState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _openclaw.dispose();
    _clap.dispose();
    _sleep.dispose();
    _wakeup.dispose();
    _rampTimer?.cancel();
    _musicTimer?.cancel();
    _clapIndicatorTimer?.cancel();
    super.dispose();
  }
}
