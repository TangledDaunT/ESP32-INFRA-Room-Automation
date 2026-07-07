import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';

class LuxDial extends StatelessWidget {
  const LuxDial({
    super.key,
    required this.luxValue,
    this.maxLux = 1000,
  });

  final double luxValue;
  final double maxLux;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: luxValue),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: LuxDialPainter(
              luxValue: value,
              maxLux: maxLux,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Symbols.light_mode,
                    size: 20,
                    color: AppColors.white60,
                    fill: 0,
                    weight: 200,
                    opticalSize: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.toStringAsFixed(0),
                    style: AppTextStyles.tabular(
                      AppTextStyles.displayLG().copyWith(fontSize: 40),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LUX',
                    style: AppTextStyles.labelSM(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LuxDialPainter extends CustomPainter {
  LuxDialPainter({
    required this.luxValue,
    required this.maxLux,
  });

  final double luxValue;
  final double maxLux;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -225 * math.pi / 180;
    const totalSweep = 270 * math.pi / 180;
    final sweepFraction = (luxValue / maxLux).clamp(0.0, 1.0);
    final progressSweep = totalSweep * sweepFraction;

    final outerRing = Paint()
      ..color = AppColors.white05
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(center, radius + 6, outerRing);

    final dashedRing = Paint()
      ..color = AppColors.white20
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    const dashSweep = 0.015;
    const gapSweep = 0.06;
    for (double angle = 0; angle < math.pi * 2; angle += dashSweep + gapSweep) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 8),
        angle,
        dashSweep,
        false,
        dashedRing,
      );
    }

    final trackPaint = Paint()
      ..color = AppColors.white08
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(rect, startAngle, totalSweep, false, trackPaint);

    if (progressSweep > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + progressSweep,
          colors: const [AppColors.white90, AppColors.white20],
        ).createShader(rect);
      canvas.drawArc(rect, startAngle, progressSweep, false, progressPaint);

      final endAngle = startAngle + progressSweep;
      final dot =
          center + Offset(math.cos(endAngle), math.sin(endAngle)) * radius;
      canvas.drawCircle(
        dot,
        2.25,
        Paint()..color = AppColors.white,
      );
    }

    final tickPaint = Paint()
      ..color = AppColors.white40
      ..strokeWidth = 0.5;
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final p1 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 3);
      final p2 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius + 3);
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LuxDialPainter oldDelegate) {
    return oldDelegate.luxValue != luxValue || oldDelegate.maxLux != maxLux;
  }
}
