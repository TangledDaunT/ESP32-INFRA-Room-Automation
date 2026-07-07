// lib/services/page_activity_controller.dart
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Stable index of each page inside the swipeable control deck
/// (`ControlPagesScreen`). Screens that only poll while visible compare
/// their own index against [PageActivityController.currentPage].
class ControlPageIndex {
  ControlPageIndex._();

  static const control = 0;
  static const macControl = 1;
  static const macHub = 2;
  static const macStatus = 3;
}

/// Owns the single idle-timeout timer shared by every page in the
/// swipeable control deck, and tracks which page + app-lifecycle state is
/// currently visible.
///
/// Previously each page in the deck (`ControlScreen`, `MacControlScreen`)
/// ran its own independent idle timer. Because `PageView` keeps every
/// child mounted regardless of which one is visible, an off-screen page's
/// timer could fire while the user was actively using a different page,
/// silently kicking them back to the idle screen. Centralizing the timer
/// here — reset by activity anywhere in the deck, paused while a modal
/// sub-page (Settings/Alarms/Logs) is on top — fixes that, and doubles as
/// the visibility signal pages use to pause their own network polling.
class PageActivityController extends ChangeNotifier with WidgetsBindingObserver {
  PageActivityController({
    required this.getTimeoutSeconds,
    required this.onIdle,
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  final int Function() getTimeoutSeconds;
  final VoidCallback onIdle;

  Timer? _idleTimer;
  bool _paused = false;
  int _currentPage = ControlPageIndex.control;
  bool _appResumed = true;

  int get currentPage => _currentPage;
  bool get appResumed => _appResumed;

  /// True only while [pageIndex] is the on-screen page AND the app itself
  /// is in the foreground — the condition screens should poll on.
  bool isVisible(int pageIndex) => _appResumed && _currentPage == pageIndex;

  void start() => pingActivity();

  /// Reset the idle countdown. Safe to call frequently (every tap/pan).
  void pingActivity() {
    if (_paused) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(Duration(seconds: getTimeoutSeconds()), onIdle);
  }

  void setPage(int index) {
    if (_currentPage == index) return;
    _currentPage = index;
    notifyListeners();
    pingActivity();
  }

  /// Suspend the idle countdown while a modal sub-page (Settings, Alarms,
  /// Activity Log) is pushed on top of the control deck, so its own
  /// inactivity can't pop the user all the way back to the idle screen.
  void pause() {
    _paused = true;
    _idleTimer?.cancel();
  }

  void resume() {
    _paused = false;
    pingActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }
}
