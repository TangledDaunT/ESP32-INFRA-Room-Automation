import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import '../theme.dart';
import '../widgets/lux_dial.dart';

class IdleScreen extends StatefulWidget {
  const IdleScreen({super.key});

  @override
  State<IdleScreen> createState() => _IdleScreenState();
}

class _IdleScreenState extends State<IdleScreen> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  bool _wakeFlash = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _wakeToControl() async {
    if (_navigating) {
      return;
    }
    setState(() {
      _wakeFlash = true;
      _navigating = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) {
      return;
    }
    setState(() => _wakeFlash = false);
    await Navigator.of(context).pushNamed('/control');
    if (mounted) {
      setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceProvider>().state;
    final dateText =
        DateFormat('EEEE, MMMM d, yyyy').format(_now).toUpperCase();
    final hourMinute = DateFormat('HH:mm').format(_now);
    final secondText = DateFormat('ss').format(_now);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: GestureDetector(
        onTap: _wakeToControl,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Padding(
                padding: AppSpace.pagePadding,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        hourMinute,
                                        style: AppTextStyles.tabular(
                                          AppTextStyles.displayXL(),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        switchInCurve: Curves.easeIn,
                                        child: Text(
                                          ':$secondText',
                                          key: ValueKey<String>(secondText),
                                          style: AppTextStyles.tabular(
                                            AppTextStyles.displayXL(
                                              color: AppColors.white40,
                                            ).copyWith(fontSize: 36),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpace.sm),
                                Text(
                                  dateText,
                                  style: AppTextStyles.labelLG(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            flex: 4,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 220),
                                child: LuxDial(luxValue: state.luxValue),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _IdleNavBar(onWake: _wakeToControl),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _wakeFlash ? 1 : 0,
                duration: const Duration(milliseconds: 100),
                child: Container(color: AppColors.white05),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleNavBar extends StatelessWidget {
  const _IdleNavBar({required this.onWake});

  final Future<void> Function() onWake;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IdleNavIcon(
            icon: Symbols.settings,
            onTap: () => Navigator.of(context).pushNamed('/settings'),
          ),
          const SizedBox(width: AppSpace.lg),
          _IdleNavIcon(
            icon: Symbols.brightness_medium,
            active: true,
            onTap: onWake,
          ),
          const SizedBox(width: AppSpace.lg),
          const _IdleNavIcon(
            icon: Symbols.blur_on,
          ),
        ],
      ),
    );
  }
}

class _IdleNavIcon extends StatelessWidget {
  const _IdleNavIcon({
    required this.icon,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: 22,
      color: active ? AppColors.white90 : AppColors.white40,
      fill: active ? 1 : 0,
      weight: active ? 400 : 300,
      opticalSize: 24,
    );

    final child = active
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white10,
              border: Border.all(color: AppColors.white20, width: 1),
            ),
            child: iconWidget,
          )
        : iconWidget;

    if (onTap == null) {
      return child;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
