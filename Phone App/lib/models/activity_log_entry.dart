import 'dart:convert';

enum ActivityLogType { command, alarm, automation, sensor, system }

class ActivityLogEntry {
  final String id;
  final DateTime timestamp;
  final ActivityLogType type;
  final String title;
  final String detail;

  const ActivityLogEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    required this.detail,
  });

  factory ActivityLogEntry.create({
    required ActivityLogType type,
    required String title,
    String detail = '',
  }) {
    return ActivityLogEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: type,
      title: title,
      detail: detail,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'title': title,
        'detail': detail,
      };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: ActivityLogType.values.firstWhere(
        (value) => value.name == (json['type'] as String? ?? ActivityLogType.system.name),
        orElse: () => ActivityLogType.system,
      ),
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  static List<ActivityLogEntry> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(ActivityLogEntry.fromJson)
        .toList();
  }

  static String encodeList(List<ActivityLogEntry> entries) =>
      jsonEncode(entries.map((entry) => entry.toJson()).toList());
}