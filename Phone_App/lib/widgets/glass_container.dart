import 'package:flutter/material.dart';

import '../theme.dart';

/// A reusable liquid-glass container with frosted translucent background,
/// subtle border, rounded corners, and inner highlight gradient.
///
/// Lightweight alternative to BackdropFilter for Galaxy J6 performance.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.isActive = false,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.pressed = false,
  });

  final Widget child;
  final double borderRadius;
  final bool isActive;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return AnimatedContainer(
      duration: GlassDecoration.motionMedium,
      curve: GlassDecoration.motionCurve,
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: GlassDecoration.panel(
        borderRadius: borderRadius,
        isActive: isActive,
        pressed: pressed,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.white
                            .withValues(alpha: isActive ? 0.13 : 0.08),
                        Colors.transparent,
                        Colors.black.withValues(alpha: pressed ? 0.18 : 0.08),
                      ],
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
