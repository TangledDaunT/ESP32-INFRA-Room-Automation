import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A full-height vertical brightness slider with liquid-glass aesthetic.
///
/// Designed for landscape dashboard — occupies the full height of its parent.
/// The filled portion glows proportionally to the brightness level.
/// An icon is displayed at the top and the percentage near the thumb.
class BrightnessSlider extends StatefulWidget {
  const BrightnessSlider({
    super.key,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  /// Icon displayed at the top of the slider bar.
  final IconData icon;

  /// Current brightness value (0–255).
  final double value;

  /// Called when the user drags to change the value.
  final ValueChanged<double> onChanged;

  @override
  State<BrightnessSlider> createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<BrightnessSlider> {
  bool _dragging = false;
  double _lastHapticValue = -1;

  void _triggerHapticIfNeeded(double newValue) {
    const checkpoints = [0.0, 0.5, 1.0];
    for (final cp in checkpoints) {
      final cpVal = (cp * 255).round().toDouble();
      if ((_lastHapticValue < cpVal && newValue >= cpVal) ||
          (_lastHapticValue > cpVal && newValue <= cpVal)) {
        HapticFeedback.selectionClick();
        break;
      }
    }
    _lastHapticValue = newValue;
  }

  void _handleVerticalDrag(
      DragUpdateDetails details, BoxConstraints constraints) {
    final trackHeight = constraints.maxHeight - 48; // padding for icon + bottom
    final dy = details.localPosition.dy - 24; // offset for top padding
    // Invert: top = 255, bottom = 0
    final fraction = 1.0 - (dy / trackHeight).clamp(0.0, 1.0);
    final newValue = (fraction * 255).roundToDouble();
    _triggerHapticIfNeeded(newValue);
    widget.onChanged(newValue);
  }

  void _handleTapDown(TapDownDetails details, BoxConstraints constraints) {
    final trackHeight = constraints.maxHeight - 48;
    final dy = details.localPosition.dy - 24;
    final fraction = 1.0 - (dy / trackHeight).clamp(0.0, 1.0);
    widget.onChanged((fraction * 255).roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final clampedValue = widget.value.clamp(0, 255).toDouble();
    final fraction = clampedValue / 255;
    final percent = (fraction * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight - 48;
        final filledHeight = trackHeight * fraction;

        return GestureDetector(
          onVerticalDragStart: (_) => setState(() => _dragging = true),
          onVerticalDragEnd: (_) => setState(() => _dragging = false),
          onVerticalDragUpdate: (d) => _handleVerticalDrag(d, constraints),
          onTapDown: (d) => _handleTapDown(d, constraints),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 52,
            child: Column(
              children: [
                // Icon at top
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Icon(
                    widget.icon,
                    size: 16,
                    color: fraction > 0 ? AppColors.white60 : AppColors.white20,
                    fill: fraction > 0.5 ? 1 : 0,
                    weight: 300,
                  ),
                ),
                // The track
                Expanded(
                  child: AnimatedScale(
                    duration:
                        _dragging ? Duration.zero : GlassDecoration.motionFast,
                    curve: GlassDecoration.motionCurve,
                    scale: _dragging ? 1.035 : 1,
                    child: Container(
                      width: 34,
                      decoration: GlassDecoration.bar(borderRadius: 18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      AppColors.white.withValues(alpha: 0.06),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Filled portion
                            AnimatedContainer(
                              duration: _dragging
                                  ? Duration.zero
                                  : GlassDecoration.motionFast,
                              curve: GlassDecoration.motionCurve,
                              width: 34,
                              height: filledHeight.clamp(0, trackHeight),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.zero,
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppColors.white.withValues(
                                      alpha: 0.18 + fraction * 0.16,
                                    ),
                                    AppColors.white.withValues(alpha: 0.06),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.white.withValues(
                                    alpha: 0.12 + fraction * 0.12,
                                  ),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.white.withValues(
                                      alpha: fraction * 0.12,
                                    ),
                                    blurRadius: 18,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                            // Thumb indicator at top of filled portion
                            Positioned(
                              bottom: (filledHeight - 2).clamp(0, trackHeight),
                              child: AnimatedContainer(
                                duration: _dragging
                                    ? Duration.zero
                                    : GlassDecoration.motionFast,
                                width: _dragging ? 31 : 27,
                                height: _dragging ? 4 : 3,
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(
                                    alpha: _dragging ? 0.95 : 0.68,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.white.withValues(
                                        alpha: _dragging ? 0.22 : 0.12,
                                      ),
                                      blurRadius: _dragging ? 14 : 8,
                                      spreadRadius: _dragging ? 1 : 0,
                                    ),
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Percentage at bottom
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$percent',
                    style: AppTextStyles.tabular(
                      AppTextStyles.labelSM(
                        color: fraction > 0
                            ? AppColors.white60
                            : AppColors.white20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
