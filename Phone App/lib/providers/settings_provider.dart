// lib/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  static const _key = 'openclaw_settings';
  AppSettings _settings = AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      try {
        _settings = AppSettings.fromJsonString(jsonStr);
      } catch (_) {
        _settings = AppSettings();
      }
    }
    final migrated = _migrateSettings(_settings);
    if (migrated != null) {
      _settings = migrated;
      await prefs.setString(_key, _settings.toJsonString());
    }
    _loaded = true;
    notifyListeners();
  }

  AppSettings? _migrateSettings(AppSettings settings) {
    if (settings.openclawBaseUrl == AppSettings.legacyOpenClawBaseUrl) {
      return AppSettings.fromJson(settings.toJson())
        ..openclawBaseUrl = AppSettings.currentOpenClawBaseUrl;
    }
    return null;
  }

  Future<void> save(AppSettings updated) async {
    _settings = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, updated.toJsonString());
    notifyListeners();
  }

  Future<void> reset() async {
    _settings = AppSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }
}
