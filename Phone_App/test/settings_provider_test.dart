import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw_remote/models/app_settings.dart';
import 'package:openclaw_remote/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates the old default OpenClaw URL to the current ESP address',
      () async {
    final oldSettings = AppSettings(openclawBaseUrl: 'http://192.168.1.30');
    SharedPreferences.setMockInitialValues({
      'openclaw_settings': oldSettings.toJsonString(),
    });

    final provider = SettingsProvider();
    await provider.load();

    expect(provider.settings.openclawBaseUrl, 'http://192.168.1.15');

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString('openclaw_settings');

    expect(persisted, contains('http://192.168.1.15'));
  });
}
