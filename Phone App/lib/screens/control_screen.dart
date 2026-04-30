// lib/screens/control_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../providers/device_provider.dart';
import '../theme.dart';
import '../widgets/device_button.dart';
import '../widgets/sensor_card.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final state = device.state;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ── Header ──────────────────────────────────
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPENCLAW',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        'REMOTE CONTROL',
                        style: TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 9,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _connectionBadge(state),
                ],
              ),

              const SizedBox(height: 4),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 12),

              // ── Device Controls Grid ──────────────────
              _sectionLabel('DEVICES'),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [
                  DeviceButton(
                    label: 'FAN',
                    icon: Icons.air,
                    isOn: state.fanOn,
                    color: AppTheme.colorFan,
                    onTap: () => device.setFan(!state.fanOn),
                  ),
                  DeviceButton(
                    label: 'MAIN LIGHT',
                    icon: Icons.lightbulb_outline,
                    isOn: state.lightOn,
                    color: AppTheme.colorLight,
                    onTap: () => device.setLight(!state.lightOn),
                  ),
                  DeviceButton(
                    label: 'SOCKET',
                    icon: Icons.electrical_services,
                    isOn: state.socketOn,
                    color: AppTheme.colorSocket,
                    onTap: () => device.setSocket(!state.socketOn),
                  ),
                  DeviceButton(
                    label: 'RGB STRIP',
                    icon: Icons.color_lens_outlined,
                    isOn: state.rgbOn,
                    color: AppTheme.colorRgb,
                    onTap: () => device.setRgb(!state.rgbOn),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Brightness Sliders ─────────────────────
              _sectionLabel('BRIGHTNESS'),
              const SizedBox(height: 10),

              _BrightnessSlider(
                label: 'RGB STRIP',
                icon: Icons.color_lens_outlined,
                color: AppTheme.colorRgb,
                value: state.rgbBrightness,
                onChanged: (v) => device.setRgbBrightness(v),
              ),

              const SizedBox(height: 10),

              _BrightnessSlider(
                label: 'BACKUP LIGHT',
                icon: Icons.flashlight_on_outlined,
                color: AppTheme.colorLight,
                value: state.backupBrightness,
                onChanged: (v) => device.setBackupBrightness(v),
              ),

              const SizedBox(height: 20),

              // ── Intimacy Mode ─────────────────────────
              _IntimacyTile(
                active: state.intimacyMode,
                onTap: () => device.toggleIntimacyMode(),
              ),

              const SizedBox(height: 20),

              // ── Sensors ───────────────────────────────
              _sectionLabel('SENSORS'),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: SensorCard(
                      label: 'SMOKE / MQ-2',
                      value: state.smokeValue.toStringAsFixed(0),
                      unit: 'ppm',
                      icon: Icons.air,
                      color: state.smokeAlarm ? AppTheme.danger : AppTheme.accent,
                      alert: state.smokeAlarm,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SensorCard(
                      label: 'LUMINANCE',
                      value: state.luxValue.toStringAsFixed(1),
                      unit: 'lux',
                      icon: Icons.wb_sunny_outlined,
                      color: AppTheme.colorLight,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              PresenceCard(present: state.presenceDetected),

              const SizedBox(height: 10),

              // ── Sleep State ───────────────────────────
              _SleepStateBadge(state: state.sleepState),

              const SizedBox(height: 80), // Bottom nav space
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: AppTheme.textDim,
          fontSize: 10,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _connectionBadge(state) => Row(
        children: [
          _dot(state.mqttOk, 'MQ'),
          const SizedBox(width: 8),
          _dot(state.bleOk, 'BLE'),
          const SizedBox(width: 8),
          _dot(state.openclawOk, 'OC'),
        ],
      );

  Widget _dot(bool ok, String label) => Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? AppTheme.success : AppTheme.textDim,
              boxShadow: ok
                  ? [BoxShadow(color: AppTheme.success, blurRadius: 4)]
                  : [],
            ),
          ),
          Text(label,
              style: TextStyle(color: AppTheme.textDim, fontSize: 8)),
        ],
      );
}

class _BrightnessSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int value;
  final ValueChanged<int> onChanged;

  const _BrightnessSlider({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((value / 255) * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecond,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withOpacity(0.15),
              inactiveTrackColor: AppTheme.border,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntimacyTile extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _IntimacyTile({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.colorRgb.withOpacity(0.12)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppTheme.colorRgb.withOpacity(0.5)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.mic,
              color: active ? AppTheme.colorRgb : AppTheme.textSecond,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INTIMACY MODE',
                    style: TextStyle(
                      color: active ? AppTheme.colorRgb : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    active
                        ? 'RGB reacts to sound via mic'
                        : 'RGB brightness follows sound',
                    style: TextStyle(
                      color: AppTheme.textSecond,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: active ? AppTheme.colorRgb : AppTheme.border,
              ),
              child: Align(
                alignment: active ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStateBadge extends StatelessWidget {
  final SleepState state;
  const _SleepStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == SleepState.awake) return const SizedBox.shrink();

    String text;
    Color color;
    IconData icon;

    switch (state) {
      case SleepState.sleeping:
        text = 'SLEEP MODE ACTIVE — All lights managed';
        color = AppTheme.accentDim;
        icon = Icons.bedtime;
        break;
      case SleepState.nightMode:
        text = 'NIGHT MODE — Dimmed for comfort';
        color = AppTheme.colorRgb.withOpacity(0.8);
        icon = Icons.nights_stay;
        break;
      case SleepState.wakingUp:
        text = 'WAKE-UP ROUTINE IN PROGRESS';
        color = AppTheme.colorLight;
        icon = Icons.wb_twilight;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: color, fontSize: 11, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
