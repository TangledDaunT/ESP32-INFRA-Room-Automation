import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/device_state.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/brightness_slider.dart';
import '../widgets/device_button.dart';
import '../widgets/speedometer_dial.dart';

/// Landscape fullscreen dashboard — the main control surface.
///
/// Layout:
/// ┌──────────────────────────────────────────────────┐
/// │ [STRIP]  │  [LUX DIAL]  [SMOKE DIAL]  │ [BACKUP]│
/// │  slider  │  [FAN] [LIGHT] [SOCKET] [RGB]│  slider │
/// │          │         [⚙ settings]         │         │
/// └──────────────────────────────────────────────────┘
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

String _luxLabel(double lux) {
  if (lux < 0) return 'NO SENSOR';
  if (lux < 20) return 'DARK';
  if (lux < 100) return 'DIM';
  if (lux < 300) return 'BRIGHT';
  return 'VERY BRIGHT';
}

Color _luxColor(double lux) {
  if (lux < 0) return Colors.grey;
  if (lux < 20) return const Color(0xFF5588FF);
  if (lux < 100) return const Color(0xFF88AAFF);
  if (lux < 300) return const Color(0xFFFFCC44);
  return const Color(0xFFFFAA00);
}

String _smokeLabel(double ppm) {
  if (ppm < 200) return 'NORMAL';
  if (ppm < 600) return 'ELEVATED';
  return 'ALERT';
}

Color _smokeColor(double ppm) {
  if (ppm < 200) return const Color(0xFF44DD88);
  if (ppm < 600) return const Color(0xFFFFAA00);
  return const Color(0xFFFF4444);
}

class _ControlScreenState extends State<ControlScreen>
    with SingleTickerProviderStateMixin {
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetIdleTimer());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final timeoutSeconds =
        context.read<SettingsProvider>().settings.idleTimeoutSeconds;
    _idleTimer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _openSettings() async {
    _idleTimer?.cancel();
    await Navigator.of(context).pushNamed('/settings');
    if (mounted) _resetIdleTimer();
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final state = device.state;

    final isDisconnected =
        state.openclawStatus == ConnectionStatus.disconnected;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: GestureDetector(
        onTapDown: (_) => _resetIdleTimer(),
        onPanDown: (_) => _resetIdleTimer(),
        onDoubleTap: () {
          _resetIdleTimer();
          device.simulateDoubleClap();
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isDisconnected ? 32 : 0,
              color: const Color(0xFF7A4F00),
              child: isDisconnected
                  ? const Center(
                      child: Text(
                        'ESP32 DISCONNECTED — RETRYING...',
                        style: TextStyle(
                          color: Color(0xFFFFCC44),
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // ── LEFT: Strip brightness slider ─────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: BrightnessSlider(
                  icon: Symbols.light_group,
                  value: state.rgbBrightness.toDouble(),
                  onChanged: (v) {
                    _resetIdleTimer();
                    device.setRgbBrightness(v.round());
                  },
                ),
              ),

              const SizedBox(width: 16),

              // ── CENTER: Dials + Relay buttons ─────────
              Expanded(
                child: Column(
                  children: [
                    // Top: Speedometer dials
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          // Lux dial
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: RepaintBoundary(
                                child: SpeedometerDial(
                                  value: state.luxValue,
                                  maxValue: 700,
                                  label: 'LUX',
                                  icon: Symbols.light_mode,
                                  unit: 'LX',
                                  statusLabel: _luxLabel(state.luxValue),
                                  statusColor: _luxColor(state.luxValue),
                                ),
                              ),
                            ),
                          ),
                          // Smoke dial
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: RepaintBoundary(
                                child: SpeedometerDial(
                                  value: state.smokeValue,
                                  maxValue: 3000,
                                  label: 'PPM',
                                  icon: Symbols.detector_smoke,
                                  unit: 'PPM',
                                  warningThreshold: 2800,
                                  statusLabel: _smokeLabel(state.smokeValue),
                                  statusColor: _smokeColor(state.smokeValue),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Bottom: 2×2 relay grid + settings
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: DeviceButton(
                                      icon: Symbols.mode_fan,
                                      isOn: state.fanOn,
                                      semanticLabel: 'Fan',
                                      onTap: () {
                                        _resetIdleTimer();
                                        device.setFan(!state.fanOn);
                                      },
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: DeviceButton(
                                      icon: Symbols.lightbulb,
                                      isOn: state.lightOn,
                                      semanticLabel: 'Light',
                                      onTap: () {
                                        _resetIdleTimer();
                                        device.setLight(!state.lightOn);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: DeviceButton(
                                      icon: Symbols.power,
                                      isOn: state.socketOn,
                                      semanticLabel: 'Socket',
                                      onTap: () {
                                        _resetIdleTimer();
                                        device.setSocket(!state.socketOn);
                                      },
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: DeviceButton(
                                      icon: Symbols.palette,
                                      isOn: state.rgbOn,
                                      semanticLabel: 'RGB',
                                      onTap: () {
                                        _resetIdleTimer();
                                        device.setRgb(!state.rgbOn);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Settings, Alarm, Music, Friday, & Sleep buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _BottomActionButton(
                                icon: Symbols.settings,
                                label: 'SETTINGS',
                                onTap: _openSettings,
                              ),
                              _BottomActionButton(
                                icon: Symbols.alarm,
                                label: 'ALARMS',
                                onTap: () {
                                  _idleTimer?.cancel();
                                  Navigator.of(context)
                                      .pushNamed('/alarms')
                                      .then((_) => _resetIdleTimer());
                                },
                              ),
                              _BottomActionButton(
                                icon: Symbols.history,
                                label: 'LOGS',
                                onTap: () {
                                  _idleTimer?.cancel();
                                  Navigator.of(context)
                                      .pushNamed('/activity')
                                      .then((_) => _resetIdleTimer());
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // ── RIGHT: Backup brightness slider ───────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: BrightnessSlider(
                  icon: Symbols.flashlight_on,
                  value: state.backupBrightness.toDouble(),
                  onChanged: (v) {
                    _resetIdleTimer();
                    device.setBackupBrightness(v.round());
                  },
                ),
              ),
            ],
          ),
        ),
            ),
          ],
        ),
      ),
      // Clap feedback overlay
      floatingActionButton: _ClapFeedbackOverlay(
        visible: device.showClapIndicator,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.white60;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
              weight: 300,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSM(color: color),
            ),
          ],
        ),
      ),
    );
  }
}



// ── Clap detection visual feedback ──────────────────────────
class _ClapFeedbackOverlay extends StatelessWidget {
  const _ClapFeedbackOverlay({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        opacity: visible ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          scale: visible ? 1.0 : 0.8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: GlassDecoration.panel(borderRadius: 24, isActive: true)
                .copyWith(
              boxShadow: GlassDecoration.glow(blur: 20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.hearing,
                  color: AppColors.white90,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'CLAP',
                  style: AppTextStyles.labelLG(color: AppColors.white90)
                      .copyWith(letterSpacing: 3.0, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
