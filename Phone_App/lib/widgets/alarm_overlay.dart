// lib/widgets/alarm_overlay.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';
import '../theme.dart';

/// Full-screen alarm overlay shown over both idle and control screens.
///
/// Shown when [AlarmProvider.isAlarmFiring] is true.
/// Contains: alarm label, large pulsing clock, Snooze + Quit buttons.
class AlarmOverlay extends StatefulWidget {
  const AlarmOverlay({super.key});

  @override
  State<AlarmOverlay> createState() => _AlarmOverlayState();
}

class _AlarmOverlayState extends State<AlarmOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  late final AnimationController _ringCtrl;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  static const Color _red = Color(0xFFEF4444);
  static const Color _redGlow = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Pulsing glow behind the time display
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Expanding ring animation
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _ringScale = Tween<double>(begin: 0.6, end: 1.6).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alarm = context.read<AlarmProvider>();
    final firingAlarm = alarm.firingAlarm;
    final isSmokeAlarm = firingAlarm?.kind == AlarmKind.smoke;
    final size = MediaQuery.of(context).size;
    final clockFontSize = (size.height * 0.52).clamp(80.0, 320.0);

    final hourText = DateFormat('HH').format(_now);
    final minText = DateFormat('mm').format(_now);
    final label =
      (firingAlarm?.label.isNotEmpty ?? false)
        ? firingAlarm!.label
        : (isSmokeAlarm ? 'SMOKE' : 'ALARM');

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.92),
        child: Stack(
          children: [
            // ── Pulsing red glow bloom ──────────────────────
            Center(
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Transform.scale(
                  scale: _pulseScale.value,
                  child: Container(
                    width: size.width * 0.7,
                    height: size.height * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _red.withValues(alpha: _pulseOpacity.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Expanding ring ──────────────────────────────
            Center(
              child: AnimatedBuilder(
                animation: _ringCtrl,
                builder: (_, __) => Transform.scale(
                  scale: _ringScale.value,
                  child: Opacity(
                    opacity: _ringOpacity.value,
                    child: Container(
                      width: size.height * 0.65,
                      height: size.height * 0.65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _red,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Main content ────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(fontFamily: 'Manrope').copyWith(
                      fontSize: (size.height * 0.038).clamp(12.0, 22.0),
                      fontWeight: FontWeight.w300,
                      color: _red.withValues(alpha: 0.85),
                      letterSpacing: 8.0,
                    ),
                  ),

                  SizedBox(height: size.height * 0.018),

                  // Clock display
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildDigit(hourText, clockFontSize),
                      _buildColon(clockFontSize),
                      _buildDigit(minText, clockFontSize),
                    ],
                  ),

                  SizedBox(height: size.height * 0.06),

                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isSmokeAlarm) ...[
                        _AlarmButton(
                          label: 'SNOOZE',
                          sublabel: '5 MIN',
                          color: AppColors.white90,
                          borderColor: AppColors.white40,
                          onTap: () => context.read<AlarmProvider>().snooze(),
                        ),
                        SizedBox(width: size.width * 0.04),
                      ],

                      _AlarmButton(
                        label: 'DISMISS',
                        sublabel: isSmokeAlarm ? 'SMOKE' : 'ALARM',
                        color: _red,
                        borderColor: _redGlow,
                        isDestructive: true,
                        onTap: () => context.read<AlarmProvider>().dismiss(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigit(String text, double fontSize) {
    return Text(
      text,
      style: const TextStyle(fontFamily: 'Manrope').copyWith(
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        color: Colors.white,
        height: 1.0,
        letterSpacing: -2,
        shadows: [
          Shadow(
            color: _red.withValues(alpha: 0.40),
            blurRadius: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildColon(double fontSize) {
    final dotSize = (fontSize * 0.040).clamp(12.0, 22.0);
    final gap = dotSize * 0.65;
    final hPad = (fontSize * 0.020).clamp(8.0, 18.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(dotSize),
          SizedBox(height: gap),
          _dot(dotSize),
        ],
      ),
    );
  }

  Widget _dot(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
}

class _AlarmButton extends StatelessWidget {
  const _AlarmButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.borderColor,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final String sublabel;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final btnWidth = (size.width * 0.22).clamp(130.0, 220.0);
    final btnHeight = (size.height * 0.16).clamp(56.0, 90.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: btnWidth,
        height: btnHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          color: isDestructive
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: borderColor,
            width: isDestructive ? 1.5 : 0.8,
          ),
          boxShadow: isDestructive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.labelLG(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              style: AppTextStyles.labelSM(
                  color: color.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}
