typedef AsyncCallback = Future<void> Function();

Future<void> configurePlatformRuntime({
  required bool isWeb,
  required AsyncCallback enableWakelock,
  required void Function() initForegroundTask,
}) async {
  if (isWeb) {
    return;
  }

  await enableWakelock();
  initForegroundTask();
}
