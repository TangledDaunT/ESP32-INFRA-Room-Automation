// lib/models/alarm_model.dart
import 'dart:convert';

/// Immutable alarm definition.
class AlarmModel {
  final String id;
  final int hour;
  final int minute;
  final String label;
  final bool isEnabled;

  const AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    this.isEnabled = true,
  });

  AlarmModel copyWith({
    String? id,
    int? hour,
    int? minute,
    String? label,
    bool? isEnabled,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'isEnabled': isEnabled,
      };

  factory AlarmModel.fromJson(Map<String, dynamic> json) => AlarmModel(
        id: json['id'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        label: (json['label'] as String?) ?? '',
        isEnabled: (json['isEnabled'] as bool?) ?? true,
      );

  /// Human-readable time: "07:30"
  String get timeString =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Unique key used in SharedPreferences list.
  static const String _prefsListKey = 'openclaw_alarms_v1';

  static List<AlarmModel> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(AlarmModel.fromJson)
        .toList();
  }

  static String encodeList(List<AlarmModel> alarms) =>
      jsonEncode(alarms.map((a) => a.toJson()).toList());

  static String get prefsKey => _prefsListKey;
}
