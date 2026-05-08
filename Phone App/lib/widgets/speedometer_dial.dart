import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A modern digital speedometer-style gauge widget.
///
/// Used for Lux and Smoke sensor readouts on the dashboard.
/// Resembles a car speedometer with a 270° arc, graduated ticks,
/// animated needle, and a large digital value readout in the center.
class SpeedometerDial extends StatelessWidget {
  const SpeedometerDial({
    super.key,
    required this.value,
    required this.maxValue,
    required this.label,
    required this.icon,
    this.unit = '',
    this.warningThreshold,
  });

  /// Current sensor value.
  final double value;

  /// Maximum value on the dial scale.
  final double maxValue;

  /// Label displayed below the value (e.g. "LUX", "PPM").
  final String label;

  /// Icon displayed above the value.
  final IconData icon;

  /// Unit suffix (optional, shown next to label).
  final String unit;

  /// If value exceeds this, the needle/arc turns to a warning tone.
  final double? warningThreshold;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0, maxValue)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return CustomPaint(
          painter: _SpeedometerPainter(
            value: animatedValue,
            maxValue: maxValue,
            warningThreshold: warningThreshold,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: AppColors.white40,
                  fill: 0,
                  weight: 200,
                ),
                const SizedBox(height: 4),
                Text(
                  animatedValue.toStringAsFixed(0),
                  style: AppTextStyles.tabular(
                    AppTextStyles.displayLG().copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w200,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.labelSM(color: AppColors.white40),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  _SpeedometerPainter({
    required this.value,
    required this.maxValue,
    this.warningThreshold,
  });

  final double value;
  final double maxValue;
  final double? warningThreshold;

  // Arc spans 270° starting from 135° (7 o'clock position)
  static const double _startAngle = 135 * math.pi / 180;
  static const double _sweepAngle = 270 * math.pi / 180;
  static const int _majorTicks = 10;
  static const int _minorTicksPerMajor = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final fraction = (value / maxValue).clamp(0.0, 1.0);

    _drawTrackArc(canvas, center, radius);
    _drawTicks(canvas, center, radius);
    _drawProgressArc(canvas, center, radius, fraction);
    _drawNeedle(canvas, center, radius, fraction);
    _drawCenterDot(canvas, center);
  }

  void _drawTrackArc(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = AppColors.white08
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, paint);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i <= _majorTicks * (_minorTicksPerMajor + 1); i++) {
      final isMajor = i % (_minorTicksPerMajor + 1) == 0;
      final angle = _startAngle +
          _sweepAngle * (i / (_majorTicks * (_minorTicksPerMajor + 1)));
      final innerRadius = radius - (isMajor ? 10 : 5);
      final outerRadius = radius - 1;

      final p1 =
          center + Offset(math.cos(angle), math.sin(angle)) * innerRadius;
      final p2 =
          center + Offset(math.cos(angle), math.sin(angle)) * outerRadius;

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = isMajor ? AppColors.white30 : AppColors.white10
          ..strokeWidth = isMajor ? 1.0 : 0.5,
      );
    }
  }

  void _drawProgressArc(
      Canvas canvas, Offset center, double radius, double fraction) {
    if (fraction <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final progressSweep = _sweepAngle * fraction;

    // Gradient arc
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Use a shader for the progress arc
    final isWarning = warningThreshold != null && value >= warningThreshold!;

    paint.shader = ui.Gradient.sweep(
      center,
      [
        isWarning ? const Color(0xCCFF6B6B) : AppColors.white90,
        isWarning ? const Color(0x66FF6B6B) : AppColors.white30,
      ],
      [0.0, 1.0],
      TileMode.clamp,
      _startAngle,
      _startAngle + progressSweep,
    );

    canvas.drawArc(rect, _startAngle, progressSweep, false, paint);

    // Endpoint glow dot
    final endAngle = _startAngle + progressSweep;
    final endPoint =
        center + Offset(math.cos(endAngle), math.sin(endAngle)) * radius;

    // Glow
    canvas.drawCircle(
      endPoint,
      4,
      Paint()
        ..color = (isWarning ? const Color(0x40FF6B6B) : AppColors.white20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Dot
    canvas.drawCircle(
      endPoint,
      2,
      Paint()..color = isWarning ? const Color(0xCCFF6B6B) : AppColors.white,
    );
  }

  void _drawNeedle(
      Canvas canvas, Offset center, double radius, double fraction) {
    final needleAngle = _startAngle + _sweepAngle * fraction;
    final needleLength = radius * 0.65;
    final needleTip = center +
        Offset(math.cos(needleAngle), math.sin(needleAngle)) * needleLength;

    // Needle shadow/glow
    canvas.drawLine(
      center,
      needleTip,
      Paint()
        ..color = AppColors.white10
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Needle line
    canvas.drawLine(
      center,
      needleTip,
      Paint()
        ..color = AppColors.white60
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCenterDot(Canvas canvas, Offset center) {
    // Outer ring
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = AppColors.white20
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    // Inner dot
    canvas.drawCircle(
      center,
      1.5,
      Paint()..color = AppColors.white40,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter old) =>
      old.value != value || old.maxValue != maxValue;
}
