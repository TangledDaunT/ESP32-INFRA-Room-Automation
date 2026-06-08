import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/alarm_provider.dart';
import 'providers/device_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/alarm_screen.dart';
import 'screens/control_screen.dart';
import 'screens/idle_screen.dart';
import 'screens/settings_screen.dart';
import 'services/alarm_service.dart';
import 'widgets/alarm_overlay.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await WakelockPlus.enable();
  _initForegroundTask();

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  // Load alarms before app starts
  final alarmService = AlarmService();
  await alarmService.load();
  alarmService.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(settingsProvider.settings),
        ),
        ChangeNotifierProxyProvider<DeviceProvider, AlarmProvider>(
          create: (ctx) => AlarmProvider(
            alarmService: alarmService,
            deviceProvider: ctx.read<DeviceProvider>(),
          ),
          update: (ctx, device, previous) => previous!,
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
        return Consumer<AlarmProvider>(
          builder: (context, alarm, _) {
            return Stack(
              children: [
                ScrollConfiguration(
                  behavior: const _NoGlowScrollBehavior(),
                  child: child ?? const SizedBox.shrink(),
                ),
                if (alarm.isAlarmFiring)
                  const AlarmOverlay(),
              ],
            );
          },
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
          case '/alarms':
            return buildAppRoute(
              settings: settings,
              child: const AlarmScreen(),
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
