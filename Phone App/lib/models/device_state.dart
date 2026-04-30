// lib/models/device_state.dart

enum SleepState { awake, nightMode, possiblySleeping, sleeping, wakingUp }
enum ConnectionStatus { disconnected, connecting, connected, error }

class DeviceState {
  // ── Device Controls ───────────────────────────────────
  bool fanOn;
  bool lightOn;
  bool socketOn;
  bool rgbOn;
  int rgbBrightness;      // 0–255
  int backupBrightness;   // 0–255

  // ── Sensor Readings ───────────────────────────────────
  double smokeValue;
  double luxValue;
  bool presenceDetected;
  bool smokeAlarm;

  // ── App State ─────────────────────────────────────────
  SleepState sleepState;
  bool intimacyMode;
  bool isNightMode;

  // ── Connection Status ─────────────────────────────────
  ConnectionStatus mqttStatus;
  ConnectionStatus bleStatus;
  ConnectionStatus openclawStatus;

  // ── Timestamps for automation logic ───────────────────
  DateTime? lightsOffSince;
  DateTime? presenceLastSeen;
  DateTime? presenceLostSince;
  DateTime? lastActivityTime;

  DeviceState({
    this.fanOn = false,
    this.lightOn = false,
    this.socketOn = false,
    this.rgbOn = false,
    this.rgbBrightness = 128,
    this.backupBrightness = 128,
    this.smokeValue = 0,
    this.luxValue = 0,
    this.presenceDetected = false,
    this.smokeAlarm = false,
    this.sleepState = SleepState.awake,
    this.intimacyMode = false,
    this.isNightMode = false,
    this.mqttStatus = ConnectionStatus.disconnected,
    this.bleStatus = ConnectionStatus.disconnected,
    this.openclawStatus = ConnectionStatus.disconnected,
    this.lightsOffSince,
    this.presenceLastSeen,
    this.presenceLostSince,
    this.lastActivityTime,
  });

  DeviceState copyWith({
    bool? fanOn,
    bool? lightOn,
    bool? socketOn,
    bool? rgbOn,
    int? rgbBrightness,
    int? backupBrightness,
    double? smokeValue,
    double? luxValue,
    bool? presenceDetected,
    bool? smokeAlarm,
    SleepState? sleepState,
    bool? intimacyMode,
    bool? isNightMode,
    ConnectionStatus? mqttStatus,
    ConnectionStatus? bleStatus,
    ConnectionStatus? openclawStatus,
    DateTime? lightsOffSince,
    DateTime? presenceLastSeen,
    DateTime? presenceLostSince,
    DateTime? lastActivityTime,
  }) {
    return DeviceState(
      fanOn: fanOn ?? this.fanOn,
      lightOn: lightOn ?? this.lightOn,
      socketOn: socketOn ?? this.socketOn,
      rgbOn: rgbOn ?? this.rgbOn,
      rgbBrightness: rgbBrightness ?? this.rgbBrightness,
      backupBrightness: backupBrightness ?? this.backupBrightness,
      smokeValue: smokeValue ?? this.smokeValue,
      luxValue: luxValue ?? this.luxValue,
      presenceDetected: presenceDetected ?? this.presenceDetected,
      smokeAlarm: smokeAlarm ?? this.smokeAlarm,
      sleepState: sleepState ?? this.sleepState,
      intimacyMode: intimacyMode ?? this.intimacyMode,
      isNightMode: isNightMode ?? this.isNightMode,
      mqttStatus: mqttStatus ?? this.mqttStatus,
      bleStatus: bleStatus ?? this.bleStatus,
      openclawStatus: openclawStatus ?? this.openclawStatus,
      lightsOffSince: lightsOffSince ?? this.lightsOffSince,
      presenceLastSeen: presenceLastSeen ?? this.presenceLastSeen,
      presenceLostSince: presenceLostSince ?? this.presenceLostSince,
      lastActivityTime: lastActivityTime ?? this.lastActivityTime,
    );
  }

  bool get anyLightOn => lightOn || rgbOn || backupBrightness > 0;

  bool get mqttOk => mqttStatus == ConnectionStatus.connected;
  bool get bleOk => bleStatus == ConnectionStatus.connected;
  bool get openclawOk => openclawStatus == ConnectionStatus.connected;
}
