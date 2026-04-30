import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class BrightnessSlider extends StatefulWidget {
  const BrightnessSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<BrightnessSlider> createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<BrightnessSlider> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final clampedValue = widget.value.clamp(0, 255).toDouble();
    final percent = ((clampedValue / 255) * 100).round();

    return Column(
      children: [
        Text(
          widget.label.toUpperCase(),
          style: AppTextStyles.labelSM(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpace.md),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SliderTicks(),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 1,
                      activeTrackColor: AppColors.white90,
                      inactiveTrackColor: AppColors.white20,
                      thumbColor: AppColors.white90,
                      thumbShape: _RectangularThumbShape(active: _dragging),
                      overlayColor: AppColors.white20,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: clampedValue,
                      min: 0,
                      max: 255,
                      onChangeStart: (_) => setState(() => _dragging = true),
                      onChangeEnd: (_) => setState(() => _dragging = false),
                      onChanged: widget.onChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          switchInCurve: Curves.easeIn,
          child: Text(
            '$percent%',
            key: ValueKey<int>(percent),
            style: AppTextStyles.tabular(AppTextStyles.headlineMD()),
          ),
        ),
      ],
    );
  }
}

class _SliderTicks extends StatelessWidget {
  const _SliderTicks();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (index) {
        final long = index.isEven;
        return Container(
          width: long ? 12 : 8,
          height: 1,
          color: AppColors.white20,
        );
      }),
    );
  }
}

class _RectangularThumbShape extends SliderComponentShape {
  const _RectangularThumbShape({required this.active});

  final bool active;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(8, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final glowStrength = active
        ? math.max(0.2, activationAnimation.value)
        : activationAnimation.value * 0.2;

    if (glowStrength > 0) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 8, height: 24),
        Paint()
          ..color = AppColors.white20
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawRect(
      Rect.fromCenter(center: center, width: 8, height: 24),
      Paint()..color = AppColors.white90,
    );
  }
}
