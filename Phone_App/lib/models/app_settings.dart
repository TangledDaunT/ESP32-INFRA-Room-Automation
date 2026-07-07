// lib/models/app_settings.dart
import 'dart:convert';

class AppSettings {
  static const String currentOpenClawBaseUrl = 'http://192.168.1.15';
  static const String legacyOpenClawBaseUrl = 'http://192.168.1.30';
  static const String defaultMacAgentBaseUrl = 'http://100.112.98.114:8765';

  // ── MQTT ──────────────────────────────────────────────
  String mqttBroker;
  int mqttPort;
  String mqttUsername;
  String mqttPassword;
  bool mqttUseTls;

  // ── OpenClaw HTTP ─────────────────────────────────────
  String openclawBaseUrl; // e.g. http://192.168.1.5:8000
  String macAgentBaseUrl; // Tailscale URL for the Mac control agent

  // ── BLE ───────────────────────────────────────────────
  String bleDeviceName; // Name the ESP32 advertises

  // ── MQTT Topics ───────────────────────────────────────
  String topicFan;
  String topicLight;
  String topicSocket;
  String topicRgb;
  String topicRgbBrightness;
  String topicBackupBrightness;
  String topicSmoke;
  String topicLux;
  String topicPresence;
  String topicSleepStatus;
  String topicStateSync; // Full state JSON from OpenClaw
  String topicWakeupDone; // App → OpenClaw on wakeup complete

  // ── Night Mode ────────────────────────────────────────
  int nightStartHour; // 22 = 10 PM
  int nightStartMinute;
  int nightEndHour; // 6 = 6 AM
  int nightEndMinute;
  double luxNightThreshold; // below this = night

  // ── Sleep Detection ───────────────────────────────────
  int sleepDetectionMinutes; // lights off for X mins = sleeping
  double mq2SleepThreshold; // above this = someone in room breathing
  int presenceAbsenceMinutes; // no presence for X mins = away

  // ── Wake-up Routine ───────────────────────────────────
  int wakeUpHour;
  int wakeUpMinute;
  int wakeUpRampMinutes; // how many mins before to start PWM ramp

  // ── Smoke Alarm ───────────────────────────────────────
  double smokeAlarmThreshold;

  // ── Idle Screen ───────────────────────────────────────
  int idleTimeoutSeconds; // seconds before idle screen kicks in

  // ── Clap Detection ───────────────────────────────────
  double clapDbThreshold; // dB above average to count as clap
  int clapWindowMs; // ms window to detect double clap
  // ── Advanced Clap Detection ──────────────────────────
  double clapMinFreqKhz; // start of clap band (kHz)
  double clapMaxFreqKhz; // end of clap band (kHz)
  int clapMinAttackMs; // minimum attack time (ms)
  int clapMaxDurationMs; // max clap duration (ms)
  double clapEnergyRatio; // clap band / low band threshold
  int clapCooldownMs; // debounce between double-claps (ms)
  bool clapHighPassEnabled; // enable 100Hz HPF
  bool presenceAutoRestoreLight;
  bool historySyncEnabled;
  String historySyncUrl;

  // ── Laptop Sync ───────────────────────────────────────
  String fridayBaseUrl; // OpenClaw Gateway URL (e.g. http://192.168.1.15:41262)
  String fridayHookToken; // Authorization Bearer token
  bool laptopAlarmSync; // Play alarms on laptop too

  // ── Spotify ───────────────────────────────────────────
  bool spotifyEnabled;

  // ── Motion Detection ─────────────────────────────────
  bool motionDetectEnabled;
  String motionDetectUserKey;
  String motionDetectApiToken;
  double motionSensitivity;
  int motionDebounceMs;

  AppSettings({
    // ── Real ESP32 HTTP endpoint ───────────────────────────────
    // MQTT: HiveMQ Cloud TLS (matches firmware config.h)
    this.mqttBroker = '7c7d7ed342c14133aa64550393a6e17e.s1.eu.hivemq.cloud',
    this.mqttPort = 8883,
    this.mqttUsername = 'shreyanshesp',
    this.mqttPassword = 'Shreyanshesp32',
    this.mqttUseTls = true,
    // HTTP: firmware serves on port 80 (AsyncWebServer, no base path)
    this.openclawBaseUrl = currentOpenClawBaseUrl,
    this.macAgentBaseUrl = defaultMacAgentBaseUrl,
    this.bleDeviceName = 'OpenClaw_ESP32',
    this.topicFan = 'openclaw/control/fan',
    this.topicLight = 'openclaw/control/light',
    this.topicSocket = 'openclaw/control/socket',
    this.topicRgb = 'openclaw/control/rgb',
    this.topicRgbBrightness = 'openclaw/control/rgb/brightness',
    this.topicBackupBrightness = 'openclaw/control/backup/brightness',
    this.topicSmoke = 'openclaw/sensors/smoke',
    this.topicLux = 'openclaw/sensors/lux',
    this.topicPresence = 'openclaw/sensors/presence',
    this.topicSleepStatus = 'openclaw/status/sleep',
    this.topicStateSync = 'openclaw/state',
    this.topicWakeupDone = 'openclaw/wakeup/done',
    this.nightStartHour = 22,
    this.nightStartMinute = 0,
    this.nightEndHour = 6,
    this.nightEndMinute = 0,
    this.luxNightThreshold = 50.0,
    this.sleepDetectionMinutes = 30,
    this.mq2SleepThreshold = 200.0,
    this.presenceAbsenceMinutes = 5,
    this.wakeUpHour = 7,
    this.wakeUpMinute = 0,
    this.wakeUpRampMinutes = 30,
    this.smokeAlarmThreshold = 600.0,
    this.idleTimeoutSeconds = 30,
    this.clapDbThreshold = 8.0,
    this.clapWindowMs = 1500,
    this.clapMinFreqKhz = 2.0,
    this.clapMaxFreqKhz = 8.0,
    this.clapMinAttackMs = 1,
    this.clapMaxDurationMs = 150,
    this.clapEnergyRatio = 3.0,
    this.clapCooldownMs = 2000,
    this.clapHighPassEnabled = true,
    this.presenceAutoRestoreLight = true,
    this.historySyncEnabled = false,
    this.historySyncUrl = '',
    // Laptop sync defaults
    this.fridayBaseUrl = 'http://192.168.1.15:41262',
    this.fridayHookToken = '',
    this.laptopAlarmSync = true,
    this.spotifyEnabled = true,
    this.motionDetectEnabled = false,
    this.motionDetectUserKey = '',
    this.motionDetectApiToken = '',
    this.motionSensitivity = 15.0,
    this.motionDebounceMs = 30000,
  });

  Map<String, dynamic> toJson() => {
        'mqttBroker': mqttBroker,
        'mqttPort': mqttPort,
        'mqttUsername': mqttUsername,
        'mqttPassword': mqttPassword,
        'mqttUseTls': mqttUseTls,
        'openclawBaseUrl': openclawBaseUrl,
        'macAgentBaseUrl': macAgentBaseUrl,
        'bleDeviceName': bleDeviceName,
        'topicFan': topicFan,
        'topicLight': topicLight,
        'topicSocket': topicSocket,
        'topicRgb': topicRgb,
        'topicRgbBrightness': topicRgbBrightness,
        'topicBackupBrightness': topicBackupBrightness,
        'topicSmoke': topicSmoke,
        'topicLux': topicLux,
        'topicPresence': topicPresence,
        'topicSleepStatus': topicSleepStatus,
        'topicStateSync': topicStateSync,
        'topicWakeupDone': topicWakeupDone,
        'nightStartHour': nightStartHour,
        'nightStartMinute': nightStartMinute,
        'nightEndHour': nightEndHour,
        'nightEndMinute': nightEndMinute,
        'luxNightThreshold': luxNightThreshold,
        'sleepDetectionMinutes': sleepDetectionMinutes,
        'mq2SleepThreshold': mq2SleepThreshold,
        'presenceAbsenceMinutes': presenceAbsenceMinutes,
        'wakeUpHour': wakeUpHour,
        'wakeUpMinute': wakeUpMinute,
        'wakeUpRampMinutes': wakeUpRampMinutes,
        'smokeAlarmThreshold': smokeAlarmThreshold,
        'idleTimeoutSeconds': idleTimeoutSeconds,
        'clapDbThreshold': clapDbThreshold,
        'clapWindowMs': clapWindowMs,
        'clapMinFreqKhz': clapMinFreqKhz,
        'clapMaxFreqKhz': clapMaxFreqKhz,
        'clapMinAttackMs': clapMinAttackMs,
        'clapMaxDurationMs': clapMaxDurationMs,
        'clapEnergyRatio': clapEnergyRatio,
        'clapCooldownMs': clapCooldownMs,
        'clapHighPassEnabled': clapHighPassEnabled,
        'presenceAutoRestoreLight': presenceAutoRestoreLight,
        'historySyncEnabled': historySyncEnabled,
        'historySyncUrl': historySyncUrl,
        'fridayBaseUrl': fridayBaseUrl,
        'fridayHookToken': fridayHookToken,
        'laptopAlarmSync': laptopAlarmSync,
        'spotifyEnabled': spotifyEnabled,
        'motionDetectEnabled': motionDetectEnabled,
        'motionDetectUserKey': motionDetectUserKey,
        'motionDetectApiToken': motionDetectApiToken,
        'motionSensitivity': motionSensitivity,
        'motionDebounceMs': motionDebounceMs,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        mqttBroker: json['mqttBroker'] ??
            '7c7d7ed342c14133aa64550393a6e17e.s1.eu.hivemq.cloud',
        mqttPort: json['mqttPort'] ?? 8883,
        mqttUsername: json['mqttUsername'] ?? 'shreyanshesp',
        mqttPassword: json['mqttPassword'] ?? 'Shreyanshesp32',
        mqttUseTls: json['mqttUseTls'] ?? true,
        openclawBaseUrl: json['openclawBaseUrl'] ?? currentOpenClawBaseUrl,
        macAgentBaseUrl: json['macAgentBaseUrl'] ?? defaultMacAgentBaseUrl,
        bleDeviceName: json['bleDeviceName'] ?? 'OpenClaw_ESP32',
        topicFan: json['topicFan'] ?? 'openclaw/control/fan',
        topicLight: json['topicLight'] ?? 'openclaw/control/light',
        topicSocket: json['topicSocket'] ?? 'openclaw/control/socket',
        topicRgb: json['topicRgb'] ?? 'openclaw/control/rgb',
        topicRgbBrightness:
            json['topicRgbBrightness'] ?? 'openclaw/control/rgb/brightness',
        topicBackupBrightness: json['topicBackupBrightness'] ??
            'openclaw/control/backup/brightness',
        topicSmoke: json['topicSmoke'] ?? 'openclaw/sensors/smoke',
        topicLux: json['topicLux'] ?? 'openclaw/sensors/lux',
        topicPresence: json['topicPresence'] ?? 'openclaw/sensors/presence',
        topicSleepStatus: json['topicSleepStatus'] ?? 'openclaw/status/sleep',
        topicStateSync: json['topicStateSync'] ?? 'openclaw/state',
        topicWakeupDone: json['topicWakeupDone'] ?? 'openclaw/wakeup/done',
        nightStartHour: json['nightStartHour'] ?? 22,
        nightStartMinute: json['nightStartMinute'] ?? 0,
        nightEndHour: json['nightEndHour'] ?? 6,
        nightEndMinute: json['nightEndMinute'] ?? 0,
        luxNightThreshold: (json['luxNightThreshold'] ?? 50.0).toDouble(),
        sleepDetectionMinutes: json['sleepDetectionMinutes'] ?? 30,
        mq2SleepThreshold: (json['mq2SleepThreshold'] ?? 200.0).toDouble(),
        presenceAbsenceMinutes: json['presenceAbsenceMinutes'] ?? 5,
        wakeUpHour: json['wakeUpHour'] ?? 7,
        wakeUpMinute: json['wakeUpMinute'] ?? 0,
        wakeUpRampMinutes: json['wakeUpRampMinutes'] ?? 30,
        smokeAlarmThreshold: (json['smokeAlarmThreshold'] ?? 600.0).toDouble(),
        idleTimeoutSeconds: json['idleTimeoutSeconds'] ?? 30,
        // Kept in sync with the AppSettings() constructor default above —
        // this previously defaulted to 15.0 here (and in ClapDetector's own
        // constructor) while the constructor default was 8.0, so a fresh
        // install vs. a settings blob missing this key behaved differently.
        clapDbThreshold: (json['clapDbThreshold'] ?? 8.0).toDouble(),
        clapWindowMs: json['clapWindowMs'] ?? 1500,
        clapMinFreqKhz: (json['clapMinFreqKhz'] ?? 2.0).toDouble(),
        clapMaxFreqKhz: (json['clapMaxFreqKhz'] ?? 8.0).toDouble(),
        clapMinAttackMs: json['clapMinAttackMs'] ?? 1,
        clapMaxDurationMs: json['clapMaxDurationMs'] ?? 150,
        clapEnergyRatio: (json['clapEnergyRatio'] ?? 3.0).toDouble(),
        clapCooldownMs: json['clapCooldownMs'] ?? 2000,
        clapHighPassEnabled: json['clapHighPassEnabled'] ?? true,
        presenceAutoRestoreLight: json['presenceAutoRestoreLight'] ?? true,
        historySyncEnabled: json['historySyncEnabled'] ?? false,
        historySyncUrl: json['historySyncUrl'] ?? '',
        fridayBaseUrl: json['fridayBaseUrl'] ?? 'http://192.168.1.15:41262',
        fridayHookToken: json['fridayHookToken'] ?? '',
        laptopAlarmSync: json['laptopAlarmSync'] as bool? ?? true,
        spotifyEnabled: json['spotifyEnabled'] as bool? ?? true,
        motionDetectEnabled: json['motionDetectEnabled'] as bool? ?? false,
        motionDetectUserKey: json['motionDetectUserKey'] ?? '',
        motionDetectApiToken: json['motionDetectApiToken'] ?? '',
        motionSensitivity: (json['motionSensitivity'] ?? 15.0).toDouble(),
        motionDebounceMs: json['motionDebounceMs'] ?? 30000,
      );

  String toJsonString() => jsonEncode(toJson());
  factory AppSettings.fromJsonString(String s) =>
      AppSettings.fromJson(jsonDecode(s));
}
