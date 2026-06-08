import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw_remote/models/app_settings.dart';
import 'package:openclaw_remote/services/friday_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('updates request configuration when Friday settings change', () {
    final service = FridayService(
      settings: AppSettings(
        fridayBaseUrl: 'http://192.168.1.10:41263',
        fridayHookToken: 'old-token',
      ),
    );

    expect(
      service.voiceEndpoint.toString(),
      'http://192.168.1.10:41263/hooks/voice',
    );
    expect(service.requestHeaders['Authorization'], 'Bearer old-token');

    service.updateSettings(
      AppSettings(
        fridayBaseUrl: 'http://192.168.1.20:41263',
        fridayHookToken: 'new-token',
      ),
    );

    expect(
      service.voiceEndpoint.toString(),
      'http://192.168.1.20:41263/hooks/voice',
    );
    expect(service.requestHeaders['Authorization'], 'Bearer new-token');
  });
}
