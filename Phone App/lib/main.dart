import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/device_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/control_screen.dart';
import 'screens/idle_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await WakelockPlus.enable();
  _initForegroundTask();

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(settingsProvider.settings),
        ),
      ],
      child: const OpenClawApp(),
    ),
  );
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'openclaw_clap',
      channelName: 'OpenClaw Clap Detection',
      channelDescription: 'Running in background for clap detection',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

class OpenClawApp extends StatelessWidget {
  const OpenClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenClaw Remote',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/control':
            return buildAppRoute(
              settings: settings,
              child: const ControlScreen(),
            );
          case '/settings':
            return buildAppRoute(
              settings: settings,
              child: const SettingsScreen(),
            );
          case '/':
          default:
            return buildAppRoute(
              settings: settings,
              child: const IdleScreen(),
            );
        }
      },
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
