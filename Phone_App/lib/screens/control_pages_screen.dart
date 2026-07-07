import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/page_activity_controller.dart';
import 'control_screen.dart';
import 'mac_control_screen.dart';
import 'mac_media_screen.dart';
import 'mac_status_screen.dart';

/// Swipeable deck of the four "live dashboard" pages.
///
/// `PageView` keeps every child mounted regardless of which one is
/// currently visible, so idle-timeout and background polling must be
/// coordinated centrally via [PageActivityController] rather than by each
/// page independently — see that class for why.
class ControlPagesScreen extends StatefulWidget {
  const ControlPagesScreen({super.key});

  @override
  State<ControlPagesScreen> createState() => _ControlPagesScreenState();
}

class _ControlPagesScreenState extends State<ControlPagesScreen> {
  final _pageController = PageController();
  late final PageActivityController _activity;

  @override
  void initState() {
    super.initState();
    _activity = PageActivityController(
      getTimeoutSeconds: () =>
          context.read<SettingsProvider>().settings.idleTimeoutSeconds,
      onIdle: () {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    )..start();
  }

  @override
  void dispose() {
    _activity.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PageActivityController>.value(
      value: _activity,
      child: GestureDetector(
        onTapDown: (_) => _activity.pingActivity(),
        onPanDown: (_) => _activity.pingActivity(),
        behavior: HitTestBehavior.translucent,
        child: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          reverse: true,
          onPageChanged: _activity.setPage,
          children: const [
            ControlScreen(),
            MacControlScreen(),
            MacMediaScreen(),
            MacStatusScreen(),
          ],
        ),
      ),
    );
  }
}
