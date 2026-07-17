import 'dart:convert';

enum AmbientProfile { pulse, aurora, fireplace, focus, sunrise }

enum RuleTrigger { time, lowLux, presence, smoke, macFocus }

class RoomScene {
  const RoomScene({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.light = false,
    this.fan = false,
    this.socket = false,
    this.rgb = true,
    this.rgbBrightness = 128,
    this.backupBrightness = 0,
    this.fadeMs = 700,
    this.ambientProfile,
    this.macFocus = false,
    this.isDangerous = false,
  });

  final String id;
  final String name;
  final String icon;
  final int color;
  final bool light, fan, socket, rgb;
  final int rgbBrightness, backupBrightness, fadeMs;
  final AmbientProfile? ambientProfile;
  final bool macFocus, isDangerous;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'light': light,
        'fan': fan,
        'socket': socket,
        'rgb': rgb,
        'rgbBrightness': rgbBrightness,
        'backupBrightness': backupBrightness,
        'fadeMs': fadeMs,
        'ambientProfile': ambientProfile?.name,
        'macFocus': macFocus,
        'isDangerous': isDangerous,
      };
  factory RoomScene.fromJson(Map<String, dynamic> json) => RoomScene(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String? ?? 'auto_awesome',
        color: json['color'] as int? ?? 0xFF7DD3FC,
        light: json['light'] as bool? ?? false,
        fan: json['fan'] as bool? ?? false,
        socket: json['socket'] as bool? ?? false,
        rgb: json['rgb'] as bool? ?? true,
        rgbBrightness: json['rgbBrightness'] as int? ?? 128,
        backupBrightness: json['backupBrightness'] as int? ?? 0,
        fadeMs: json['fadeMs'] as int? ?? 700,
        ambientProfile: AmbientProfile.values
            .where((v) => v.name == json['ambientProfile'])
            .firstOrNull,
        macFocus: json['macFocus'] as bool? ?? false,
        isDangerous: json['isDangerous'] as bool? ?? false,
      );

  static List<RoomScene> defaults() => const [
        RoomScene(
            id: 'focus',
            name: 'Focus',
            icon: 'psychology',
            color: 0xFF60A5FA,
            light: true,
            rgbBrightness: 110,
            macFocus: true,
            ambientProfile: AmbientProfile.focus),
        RoomScene(
            id: 'movie',
            name: 'Movie',
            icon: 'movie',
            color: 0xFFA78BFA,
            rgbBrightness: 38,
            ambientProfile: AmbientProfile.aurora),
        RoomScene(
            id: 'party',
            name: 'Party',
            icon: 'music_note',
            color: 0xFFF472B6,
            light: false,
            fan: true,
            rgbBrightness: 220,
            ambientProfile: AmbientProfile.pulse),
        RoomScene(
            id: 'sleep',
            name: 'Sleep',
            icon: 'bedtime',
            color: 0xFF818CF8,
            rgbBrightness: 32,
            fadeMs: 1800),
        RoomScene(
            id: 'away',
            name: 'Away',
            icon: 'shield',
            color: 0xFFFB7185,
            rgb: false,
            rgbBrightness: 0,
            isDangerous: true),
      ];
}

class AutomationRule {
  const AutomationRule(
      {required this.id,
      required this.name,
      required this.trigger,
      required this.sceneId,
      this.enabled = true,
      this.value = 0,
      this.cooldownMinutes = 10,
      this.lastRun});
  final String id, name, sceneId;
  final RuleTrigger trigger;
  final bool enabled;
  final double value;
  final int cooldownMinutes;
  final DateTime? lastRun;
  bool canRun(DateTime now) =>
      enabled &&
      (lastRun == null ||
          now.difference(lastRun!).inMinutes >= cooldownMinutes);
  AutomationRule copyWith({bool? enabled, DateTime? lastRun}) => AutomationRule(
      id: id,
      name: name,
      trigger: trigger,
      sceneId: sceneId,
      enabled: enabled ?? this.enabled,
      value: value,
      cooldownMinutes: cooldownMinutes,
      lastRun: lastRun ?? this.lastRun);
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trigger': trigger.name,
        'sceneId': sceneId,
        'enabled': enabled,
        'value': value,
        'cooldownMinutes': cooldownMinutes,
        'lastRun': lastRun?.toIso8601String()
      };
  factory AutomationRule.fromJson(Map<String, dynamic> j) => AutomationRule(
      id: j['id'] as String,
      name: j['name'] as String,
      trigger: RuleTrigger.values.firstWhere((v) => v.name == j['trigger'],
          orElse: () => RuleTrigger.time),
      sceneId: j['sceneId'] as String,
      enabled: j['enabled'] as bool? ?? true,
      value: (j['value'] ?? 0).toDouble(),
      cooldownMinutes: j['cooldownMinutes'] as int? ?? 10,
      lastRun: j['lastRun'] == null
          ? null
          : DateTime.tryParse(j['lastRun'] as String));
  static String encode(List<AutomationRule> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
  static List<AutomationRule> decode(String raw) => (jsonDecode(raw) as List)
      .map((e) => AutomationRule.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

class RoomTelemetry {
  const RoomTelemetry(
      this.at, this.lux, this.smoke, this.present, this.activeDevices);
  final DateTime at;
  final double lux, smoke;
  final bool present;
  final int activeDevices;
  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'lux': lux,
        'smoke': smoke,
        'present': present,
        'active': activeDevices
      };
  factory RoomTelemetry.fromJson(Map<String, dynamic> j) => RoomTelemetry(
      DateTime.parse(j['at'] as String),
      (j['lux'] ?? 0).toDouble(),
      (j['smoke'] ?? 0).toDouble(),
      j['present'] as bool? ?? false,
      j['active'] as int? ?? 0);
}
