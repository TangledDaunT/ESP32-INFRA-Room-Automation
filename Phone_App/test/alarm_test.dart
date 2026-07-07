import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openclaw_remote/models/alarm_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AlarmModel Tests', () {
    test('JSON serialization & deserialization', () {
      const alarm = AlarmModel(
        id: '1',
        hour: 8,
        minute: 30,
        label: 'Wake Up',
        isEnabled: true,
      );

      final jsonMap = alarm.toJson();
      expect(jsonMap['id'], '1');
      expect(jsonMap['hour'], 8);
      expect(jsonMap['minute'], 30);
      expect(jsonMap['label'], 'Wake Up');
      expect(jsonMap['isEnabled'], true);

      final decoded = AlarmModel.fromJson(jsonMap);
      expect(decoded.id, '1');
      expect(decoded.hour, 8);
      expect(decoded.minute, 30);
      expect(decoded.label, 'Wake Up');
      expect(decoded.isEnabled, true);
    });

    test('timeString formatted correctly', () {
      const alarm1 = AlarmModel(id: '1', hour: 8, minute: 5, label: '');
      expect(alarm1.timeString, '08:05');

      const alarm2 = AlarmModel(id: '2', hour: 20, minute: 30, label: '');
      expect(alarm2.timeString, '20:30');
    });
  });
}
