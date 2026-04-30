// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'providers/device_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/idle_screen.dart';
import 'screens/control_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full-screen immersive — hide status & nav bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Portrait only (control panel UX)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Keep screen on always
  await WakelockPlus.enable();

  // Init foreground task for background clap detection
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
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _navIndex = 0;
  bool _isIdle = false;
  Timer? _idleTimer;
  DateTime _lastInteraction = DateTime.now();

  final List<Widget> _screens = const [
    ControlScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetIdleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final settings = context.read<SettingsProvider>().settings;
    _idleTimer = Timer(Duration(seconds: settings.idleTimeoutSeconds), () {
      if (mounted) setState(() => _isIdle = true);
    });
  }

  void _onActivity() {
    if (_isIdle) setState(() => _isIdle = false);
    _resetIdleTimer();
    _lastInteraction = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    if (_isIdle) {
      return IdleScreen(onWake: _onActivity);
    }

    return GestureDetector(
      onTap: _onActivity,
      onPanDown: (_) => _onActivity(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: IndexedStack(
          index: _navIndex,
          children: _screens,
        ),
        bottomNavigationBar: _BottomNav(
          index: _navIndex,
          onTap: (i) {
            _onActivity();
            setState(() => _navIndex = i);
          },
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: 'CONTROL',
            active: index == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'SETTINGS',
            active: index == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? activeIcon : icon,
                color: active ? AppTheme.accent : AppTheme.textDim,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppTheme.accent : AppTheme.textDim,
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
