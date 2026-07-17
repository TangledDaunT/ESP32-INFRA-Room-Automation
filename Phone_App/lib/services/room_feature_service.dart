import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room_features.dart';

class RoomFeatureService extends ChangeNotifier {
  static const _scenesKey = 'room_scenes_v1', _rulesKey = 'room_rules_v1', _telemetryKey = 'room_telemetry_v1';
  List<RoomScene> _scenes = RoomScene.defaults();
  List<AutomationRule> _rules = const [];
  List<RoomTelemetry> _telemetry = const [];
  List<RoomScene> get scenes => List.unmodifiable(_scenes);
  List<AutomationRule> get rules => List.unmodifiable(_rules);
  List<RoomTelemetry> get telemetry => List.unmodifiable(_telemetry);
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final scenes = p.getString(_scenesKey);
    if (scenes != null) _scenes = (jsonDecode(scenes) as List).map((e) => RoomScene.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final rules = p.getString(_rulesKey); if (rules != null) _rules = AutomationRule.decode(rules);
    final telemetry = p.getString(_telemetryKey); if (telemetry != null) _telemetry = (jsonDecode(telemetry) as List).map((e) => RoomTelemetry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    notifyListeners();
  }
  Future<void> _save() async { final p = await SharedPreferences.getInstance(); await p.setString(_scenesKey, jsonEncode(_scenes.map((e) => e.toJson()).toList())); await p.setString(_rulesKey, AutomationRule.encode(_rules)); await p.setString(_telemetryKey, jsonEncode(_telemetry.map((e) => e.toJson()).toList())); }
  Future<void> saveRule(AutomationRule rule) async { final i = _rules.indexWhere((e) => e.id == rule.id); if (i < 0) {_rules = [..._rules, rule];} else {_rules[i] = rule;} await _save(); notifyListeners(); }
  Future<void> toggleRule(AutomationRule rule) => saveRule(rule.copyWith(enabled: !rule.enabled));
  Future<void> record(RoomTelemetry value) async { if (_telemetry.isNotEmpty && value.at.difference(_telemetry.first.at).inMinutes < 2) return; _telemetry = [value, ..._telemetry].take(360).toList(); await _save(); notifyListeners(); }
  Future<void> markRun(String id) async { final i = _rules.indexWhere((e) => e.id == id); if (i >= 0) {_rules[i] = _rules[i].copyWith(lastRun: DateTime.now()); await _save(); notifyListeners();} }
}
