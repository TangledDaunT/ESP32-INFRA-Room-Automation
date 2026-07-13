import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw_remote/models/app_settings.dart';

void main() {
  test('defaults OpenClaw base URL to the current ESP address', () {
    final settings = AppSettings();

    expect(settings.openclawBaseUrl, 'http://192.168.1.15');
  });

  test('persists Mac agent Tailscale URL', () {
    final settings = AppSettings(macAgentBaseUrl: 'http://100.64.1.2:8765');
    final restored = AppSettings.fromJsonString(settings.toJsonString());

    expect(restored.macAgentBaseUrl, 'http://100.64.1.2:8765');
  });

  test('persists motion detection alerts and tuning', () {
    final settings = AppSettings(
      motionDetectEnabled: true,
      motionDetectUserKey: 'user-key',
      motionDetectApiToken: 'api-token',
      motionSensitivity: 12,
      motionDebounceMs: 45000,
      motionUseFrontCamera: true,
      motionStealthEnabled: true,
    );

    final restored = AppSettings.fromJsonString(settings.toJsonString());

    expect(restored.motionDetectEnabled, isTrue);
    expect(restored.motionDetectUserKey, 'user-key');
    expect(restored.motionDetectApiToken, 'api-token');
    expect(restored.motionSensitivity, 12);
    expect(restored.motionDebounceMs, 45000);
    expect(restored.motionUseFrontCamera, isTrue);
    expect(restored.motionStealthEnabled, isTrue);
  });
}
