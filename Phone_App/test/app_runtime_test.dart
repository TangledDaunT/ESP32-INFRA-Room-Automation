import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw_remote/app_runtime.dart';

void main() {
  test('skips mobile-only runtime hooks on web', () async {
    var wakelockCalls = 0;
    var foregroundTaskCalls = 0;

    await configurePlatformRuntime(
      isWeb: true,
      enableWakelock: () async {
        wakelockCalls++;
      },
      initForegroundTask: () {
        foregroundTaskCalls++;
      },
    );

    expect(wakelockCalls, 0);
    expect(foregroundTaskCalls, 0);
  });

  test('runs mobile runtime hooks off web', () async {
    var wakelockCalls = 0;
    var foregroundTaskCalls = 0;

    await configurePlatformRuntime(
      isWeb: false,
      enableWakelock: () async {
        wakelockCalls++;
      },
      initForegroundTask: () {
        foregroundTaskCalls++;
      },
    );

    expect(wakelockCalls, 1);
    expect(foregroundTaskCalls, 1);
  });
}
