// lib/providers/device_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;

import '../models/app_settings.dart';
import '../models/device_state.dart';
import '../services/activity_log_service.dart';
import '../services/alarm_service.dart';
import '../services/clap_detector.dart';
import '../services/openclaw_service.dart';
import '../services/sleep_service.dart';
import '../services/spotify_service.dart';
import '../models/spotify_track.dart';
import '../services/wakeup_service.dart';

class DeviceProvider extends ChangeNotifier with WidgetsBindingObserver {
  late final OpenClawService _openclaw;
  late final ClapDetector _clap;
  late final SleepService _sleep;
  late final WakeupService _wakeup;
  late final SpotifyService _spotify;
  final ActivityLogService _activityLog;
  AlarmService? _alarmService;

  VoidCallback? onSmokeAlarmDetected;

  DeviceState _state = DeviceState();
  AppSettings _settings;

  // PWM ramp for clap-triggered RGB
  Timer? _rampTimer;
  Timer? _clapIndicatorTimer;
  bool _showClapIndicator = false;
  bool _smokeAlarmLatched = false;
  bool _clapDetectorHealthy = true;

  DeviceProvider(
    this._settings,
    this._activityLog,
  ) {
    _openclaw = OpenClawService(_settings);
    _clap = ClapDetector(
      clapDbThreshold: _settings.clapDbThreshold,
      clapWindowMs: _settings.clapWindowMs,
    );
    _sleep = SleepService(_settings);
    _wakeup = WakeupService(_settings);
    _spotify = SpotifyService(_settings);

    _setupCallbacks();
    _init();
  }

  /// Set alarm service reference for sleep mode integration
  void setAlarmService(AlarmService service) {
    _alarmService = service;
    _alarmService?.updateSettings(_settings);
  }

  DeviceState get state => _state;
  bool get showClapIndicator => _showClapIndicator;
  bool get clapDetectorHealthy => _clapDetectorHealthy;
  AppSettings get settings => _settings;
  SpotifyTrack? get currentTrack => _spotify.currentTrack;

  void _setupCallbacks() {
    // ── OpenClaw state sync ────────────────────────────
    _openclaw.onStateReceived = _onOpenClawState;
    _openclaw.onConnected = () {
      _updateState(_state.copyWith(openclawStatus: ConnectionStatus.connected));
    };
    _openclaw.onDisconnected = () {
      _updateState(
          _state.copyWith(openclawStatus: ConnectionStatus.disconnected));
    };

    // ── Clap detection ────────────────────────────────
    _clap.onDoubleClap = _handleDoubleClap;
    _clap.onSingleClap = _onSingleClap;
    _clap.onClapDetectorFailed = () {
      _clapDetectorHealthy = false;
      notifyListeners();
    };
    _clap.onClapDetectorRecovered = () {
      _clapDetectorHealthy = true;
      notifyListeners();
    };

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

    // ── Spotify ───────────────────────────────────────
    _spotify.onTrackChanged = () => notifyListeners();

    // ── Wake-up service ───────────────────────────────
    _wakeup.onRgbOn = () => setRgb(true);
    _wakeup.onRgbBrightness = (b) => setRgbBrightness(b);
    _wakeup.onLightOn = () => setLight(true);
    _wakeup.onWakeupComplete = () {
      _sleep.forceState(SleepState.awake);
    };
  }

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);

    // Connect WebSocket
    _openclaw.connect();

    // Start clap detection on platforms that support isolates and mic capture.
    if (!kIsWeb) {
      await _clap.start();
    }

    // Start sleep service
    _sleep.start();

    // Start wake-up scheduler
    _wakeup.start();

    // Start Spotify polling
    _spotify.start();
  }

  // Pause network polling that has no value while the app isn't on screen
  // (e.g. device locked/backgrounded); resume it once foregrounded again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _spotify.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _spotify.stop();
    }
  }

  // ── Device Control ────────────────────────────────────

  void setFan(bool on) {
    if (_state.fanOn == on) return;
    _updateState(_state.copyWith(fanOn: on));
    _openclaw.setRelay(1, on); // channel 1 = Fan
    _logCommand('Fan', on ? 'ON' : 'OFF');
    _notifyActivity();
  }

  void setLight(bool on) {
    if (_state.lightOn == on) return;
    _updateState(_state.copyWith(lightOn: on));
    _openclaw.setRelay(0, on); // channel 0 = Light
    _logCommand('Light', on ? 'ON' : 'OFF');
    _notifyActivity();
  }

  void setSocket(bool on) {
    if (_state.socketOn == on) return;
    _updateState(_state.copyWith(socketOn: on));
    _openclaw.setRelay(3, on); // channel 3 = Socket
    _logCommand('Socket', on ? 'ON' : 'OFF');
    _notifyActivity();
  }

  void setRgb(bool on) {
    if (_state.rgbOn == on) return;
    _updateState(_state.copyWith(rgbOn: on));
    _openclaw.setRelay(2, on); // channel 2 = RGB
    _logCommand('RGB', on ? 'ON' : 'OFF');
    _notifyActivity();
  }

  void setRgbBrightness(int brightness) {
    if (_state.rgbBrightness == brightness) return;
    _updateState(_state.copyWith(rgbBrightness: brightness));
    _openclaw.setStripBrightness(brightness);
    _logCommand('RGB brightness', '$brightness');
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
    _logCommand('Backup brightness', '$brightness');
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
        normalised['light'] = relays[0] == true;
        normalised['fan'] = relays[1] == true;
        normalised['rgb'] = relays[2] == true;
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
    if (data.containsKey('lux')) normalised['lux'] = data['lux'];

    _parseFullState(normalised);
  }

  void _parseFullState(Map<String, dynamic> data) {
    final previousPresence = _state.presenceDetected;
    final previousSmokeAlarm = _state.smokeAlarm;
    final smokeValue = (data['smoke'] ?? _state.smokeValue).toDouble();
    final presenceDetected = data['presence'] ?? _state.presenceDetected;
    final smokeAlarm = smokeValue >= _settings.smokeAlarmThreshold;

    _updateState(_state.copyWith(
      fanOn: data['fan'] ?? _state.fanOn,
      lightOn: data['light'] ?? _state.lightOn,
      socketOn: data['socket'] ?? _state.socketOn,
      rgbOn: data['rgb'] ?? _state.rgbOn,
      rgbBrightness: data['rgb_brightness'] ?? _state.rgbBrightness,
      backupBrightness: data['backup_brightness'] ?? _state.backupBrightness,
      smokeValue: smokeValue,
      luxValue: (data['lux'] ?? _state.luxValue).toDouble(),
      presenceDetected: presenceDetected,
      smokeAlarm: smokeAlarm,
    ));

    if (presenceDetected != previousPresence) {
      _activityLog.addSensor(
        'Presence ${presenceDetected ? 'detected' : 'lost'}',
        presenceDetected
            ? 'ESP32 radar reports room occupied'
            : 'ESP32 radar reports room empty',
      );
      if (presenceDetected &&
          _settings.presenceAutoRestoreLight &&
          !_state.lightOn) {
        _activityLog.addAutomation('Presence restore light',
            'Turning light on because presence returned');
        setLight(true);
      }
    }

    if (smokeAlarm && !previousSmokeAlarm && !_smokeAlarmLatched) {
      _smokeAlarmLatched = true;
      _activityLog.addSensor(
        'Smoke threshold crossed',
        'Smoke value ${smokeValue.toStringAsFixed(1)} >= ${_settings.smokeAlarmThreshold.toStringAsFixed(1)}',
      );
      onSmokeAlarmDetected?.call();
    } else if (!smokeAlarm) {
      _smokeAlarmLatched = false;
    }

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
    // Toggle behavior: if anything is on, fade off; otherwise turn everything on
    final bool anythingOn = _state.anyLightOn ||
        _state.fanOn ||
        _state.lightOn ||
        _state.socketOn ||
        _state.rgbOn ||
        _state.rgbBrightness > 0;

    if (anythingOn) {
      _turnOffAllWithFade();
    } else {
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
  }

  void _turnOffAllWithFade() {
    final startBrightness = _state.rgbBrightness;
    const steps = 10;
    const stepDuration = Duration(milliseconds: 50);

    var step = 0;
    _rampTimer?.cancel();
    _rampTimer = Timer.periodic(stepDuration, (timer) {
      step++;
      final newBrightness =
          (startBrightness * (1 - step / steps)).round().clamp(0, 255);
      setRgbBrightnessFast(newBrightness);

      if (step >= steps) {
        timer.cancel();
        // Now turn off relays
        setRgb(false);
        setLight(false);
        setFan(false);
        setSocket(false);
        setBackupBrightness(0);
      }
    });
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
      setRgbBrightnessFast(brightness);
      if (step >= steps) {
        t.cancel();
        _updateState(_state.copyWith(
            rgbBrightness: brightness)); // trigger UI update at end
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

  // ── Settings Update ───────────────────────────────────

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    _openclaw.updateSettings(settings);
    _sleep.updateSettings(settings);
    _wakeup.updateSettings(settings);
    _clap.updateSettings(settings.toJson());
    _spotify.updateSettings(settings);
    _alarmService?.updateSettings(settings);
    await _activityLog.updateSettings(settings);

    notifyListeners();
  }

  void _logCommand(String target, String value) {
    unawaited(_activityLog.addCommand(target, value));
  }

  void _updateState(DeviceState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openclaw.dispose();
    _clap.dispose();
    _sleep.dispose();
    _wakeup.dispose();
    _spotify.dispose();
    _rampTimer?.cancel();
    _clapIndicatorTimer?.cancel();
    super.dispose();
  }
}
