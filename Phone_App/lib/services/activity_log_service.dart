import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_log_entry.dart';
import '../models/app_settings.dart';

class ActivityLogService extends ChangeNotifier {
  static const String _prefsKey = 'openclaw_activity_log_v1';

  final List<ActivityLogEntry> _entries = [];
  AppSettings _settings;

  ActivityLogService(this._settings);

  List<ActivityLogEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return;

    try {
      _entries
        ..clear()
        ..addAll(ActivityLogEntry.decodeList(json));
    } catch (_) {
      _entries.clear();
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, ActivityLogEntry.encodeList(_entries.take(200).toList()));
  }

  Future<void> addCommand(String title, String detail) async {
    await addEntry(ActivityLogEntry.create(
      type: ActivityLogType.command,
      title: title,
      detail: detail,
    ));
  }

  Future<void> addAlarm(String title, String detail) async {
    await addEntry(ActivityLogEntry.create(
      type: ActivityLogType.alarm,
      title: title,
      detail: detail,
    ));
  }

  Future<void> addAutomation(String title, String detail) async {
    await addEntry(ActivityLogEntry.create(
      type: ActivityLogType.automation,
      title: title,
      detail: detail,
    ));
  }

  Future<void> addSensor(String title, String detail) async {
    await addEntry(ActivityLogEntry.create(
      type: ActivityLogType.sensor,
      title: title,
      detail: detail,
    ));
  }

  Future<void> addSystem(String title, String detail) async {
    await addEntry(ActivityLogEntry.create(
      type: ActivityLogType.system,
      title: title,
      detail: detail,
    ));
  }

  Future<void> addEntry(ActivityLogEntry entry) async {
    _entries.insert(0, entry);
    if (_entries.length > 200) {
      _entries.removeRange(200, _entries.length);
    }
    notifyListeners();
    unawaited(_persist());
    unawaited(_syncToLaptop(entry));
  }

  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _syncToLaptop(ActivityLogEntry entry) async {
    if (!_settings.historySyncEnabled) return;
    final endpoint = _settings.historySyncUrl.trim();
    if (endpoint.isEmpty) return;

    try {
      await http.post(
        Uri.parse(endpoint),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source': 'openclaw-android',
          'entry': entry.toJson(),
        }),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Best-effort sync only.
    }
  }
}