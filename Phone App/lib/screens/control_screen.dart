import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/device_state.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/brightness_slider.dart';
import '../widgets/device_button.dart';
import '../widgets/sensor_card.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotController;
  Timer? _idleTimer;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetIdleTimer());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _clockTimer?.cancel();
    _dotController.dispose();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final timeoutSeconds =
        context.read<SettingsProvider>().settings.idleTimeoutSeconds;
    _idleTimer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _openSettings() async {
    _idleTimer?.cancel();
    await Navigator.of(context).pushNamed('/settings');
    if (mounted) {
      _resetIdleTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final state = device.state;
    final connectedCount = [
      state.mqttOk,
      state.bleOk,
      state.openclawOk,
    ].where((value) => value).length;
    final isOnline = connectedCount > 0;
    final statusLabel = connectedCount == 3
        ? 'ONLINE'
        : connectedCount > 0
            ? 'PARTIAL'
            : 'OFFLINE';
    final dateLabel = DateFormat('EEE MMM d').format(_now).toUpperCase();
    final timeLabel = DateFormat('HH:mm').format(_now);
    final secondsLabel = DateFormat('ss').format(_now);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: GestureDetector(
        onTapDown: (_) => _resetIdleTimer(),
        onPanDown: (_) => _resetIdleTimer(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Padding(
            padding: AppSpace.pagePadding,
            child: Column(
              children: [
                _Header(
                  controller: _dotController,
                  connectedCount: connectedCount,
                  isOnline: isOnline,
                  statusLabel: statusLabel,
                  timeLabel: timeLabel,
                  secondsLabel: secondsLabel,
                  dateLabel: dateLabel,
                ),
                const SizedBox(height: AppSpace.xl),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _SensorColumn(state: state),
                      ),
                      const VerticalDivider(
                        color: AppColors.white20,
                        thickness: 1,
                        width: 1,
                      ),
                      Expanded(
                        child: _RelayColumn(
                          state: state,
                          device: device,
                          onActivity: _resetIdleTimer,
                        ),
                      ),
                      const VerticalDivider(
                        color: AppColors.white20,
                        thickness: 1,
                        width: 1,
                      ),
                      Expanded(
                        child: _BrightnessColumn(
                          state: state,
                          device: device,
                          onActivity: _resetIdleTimer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _Footer(
                  intimacyMode: state.intimacyMode,
                  onSettings: _openSettings,
                  onTune: () {
                    _resetIdleTimer();
                    device.toggleIntimacyMode();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.connectedCount,
    required this.isOnline,
    required this.statusLabel,
    required this.timeLabel,
    required this.secondsLabel,
    required this.dateLabel,
  });

  final AnimationController controller;
  final int connectedCount;
  final bool isOnline;
  final String statusLabel;
  final String timeLabel;
  final String secondsLabel;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        timeLabel,
                        style: AppTextStyles.tabular(
                          AppTextStyles.headlineLG(),
                        ),
                      ),
                      const SizedBox(width: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        switchInCurve: Curves.easeIn,
                        child: Text(
                          ':$secondsLabel',
                          key: ValueKey<String>(secondsLabel),
                          style: AppTextStyles.tabular(
                            AppTextStyles.headlineLG(
                              color: AppColors.white40,
                            ).copyWith(fontSize: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SYS.TIME.SYNC // $dateLabel',
                    style: AppTextStyles.labelSM(),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SYSTEM STATUS',
                    style: AppTextStyles.labelSM(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _PulsingDot(
                        controller: controller,
                        visible: isOnline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: AppTextStyles.labelLG(
                          color:
                              isOnline ? AppColors.white90 : AppColors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConnectionStatusBars(activeCount: connectedCount),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.white20, thickness: 1, height: 1),
      ],
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({
    required this.controller,
    required this.visible,
  });

  final AnimationController controller;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final opacity = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
    final scale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );

    return FadeTransition(
      opacity: visible ? opacity : const AlwaysStoppedAnimation<double>(0.35),
      child: ScaleTransition(
        scale: visible ? scale : const AlwaysStoppedAnimation<double>(0.8),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: visible ? AppColors.white : AppColors.white40,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SensorColumn extends StatelessWidget {
  const _SensorColumn({required this.state});

  final DeviceState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SENSOR.DATA', style: AppTextStyles.labelLG()),
          const SizedBox(height: AppSpace.xl),
          SensorCard(
            icon: Symbols.person,
            label: 'PRESENCE',
            value: state.presenceDetected ? 'ACTIVE' : 'AWAY',
            valueStyle: AppTextStyles.bodyLG(
              color: state.presenceDetected
                  ? AppColors.white90
                  : AppColors.white60,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          SensorCard(
            icon: Symbols.light_mode,
            label: 'LUX',
            value: state.luxValue.toStringAsFixed(0),
            unit: 'LX',
          ),
          const SizedBox(height: AppSpace.xl),
          SensorCard(
            icon: Symbols.detector_smoke,
            label: 'SMOKE',
            value: state.smokeValue.round().toString().padLeft(3, '0'),
            unit: 'PPM',
          ),
        ],
      ),
    );
  }
}

class _RelayColumn extends StatelessWidget {
  const _RelayColumn({
    required this.state,
    required this.device,
    required this.onActivity,
  });

  final DeviceState state;
  final DeviceProvider device;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RELAY.CTRL', style: AppTextStyles.labelLG()),
          const SizedBox(height: AppSpace.xl),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: AppSpace.sm,
              mainAxisSpacing: AppSpace.sm,
              childAspectRatio: 0.92,
              children: [
                DeviceButton(
                  icon: Symbols.mode_fan,
                  label: 'FAN',
                  isOn: state.fanOn,
                  onTap: () {
                    onActivity();
                    device.setFan(!state.fanOn);
                  },
                ),
                DeviceButton(
                  icon: Symbols.lightbulb,
                  label: 'LIGHT',
                  isOn: state.lightOn,
                  onTap: () {
                    onActivity();
                    device.setLight(!state.lightOn);
                  },
                ),
                DeviceButton(
                  icon: Symbols.power,
                  label: 'SOCKET',
                  isOn: state.socketOn,
                  onTap: () {
                    onActivity();
                    device.setSocket(!state.socketOn);
                  },
                ),
                DeviceButton(
                  icon: Symbols.palette,
                  label: 'RGB',
                  isOn: state.rgbOn,
                  onTap: () {
                    onActivity();
                    device.setRgb(!state.rgbOn);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrightnessColumn extends StatelessWidget {
  const _BrightnessColumn({
    required this.state,
    required this.device,
    required this.onActivity,
  });

  final DeviceState state;
  final DeviceProvider device;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BRIGHTNESS.LVL', style: AppTextStyles.labelLG()),
          const SizedBox(height: AppSpace.xl),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: BrightnessSlider(
                    label: 'RGB STRIP',
                    value: state.rgbBrightness.toDouble(),
                    onChanged: (value) {
                      onActivity();
                      device.setRgbBrightness(value.round());
                    },
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: BrightnessSlider(
                    label: 'BACKUP',
                    value: state.backupBrightness.toDouble(),
                    onChanged: (value) {
                      onActivity();
                      device.setBackupBrightness(value.round());
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.intimacyMode,
    required this.onSettings,
    required this.onTune,
  });

  final bool intimacyMode;
  final VoidCallback onSettings;
  final VoidCallback onTune;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: AppColors.white20, thickness: 1, height: 1),
        SizedBox(
          height: 48,
          child: Row(
            children: [
              _FooterIconButton(
                icon: Symbols.settings,
                onTap: onSettings,
              ),
              const SizedBox(width: AppSpace.sm),
              _FooterIconButton(
                icon: Symbols.tune,
                active: intimacyMode,
                onTap: onTune,
              ),
              const Spacer(),
              Text(
                kUiSignature,
                style: AppTextStyles.labelSM(color: AppColors.white30),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  const _FooterIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: active
            ? BoxDecoration(
                color: AppColors.white10,
                border: Border.all(color: AppColors.white20, width: 1),
              )
            : null,
        child: Icon(
          icon,
          size: 20,
          color: active ? AppColors.white90 : AppColors.white40,
          fill: active ? 1 : 0,
          weight: active ? 400 : 300,
          opticalSize: 24,
        ),
      ),
    );
  }
}
