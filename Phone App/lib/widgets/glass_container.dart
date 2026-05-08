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
  });

  final Widget child;
  final double borderRadius;
  final bool isActive;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: GlassDecoration.panel(
        borderRadius: borderRadius,
        isActive: isActive,
      ).copyWith(
        boxShadow: isActive ? GlassDecoration.glow() : null,
      ),
      child: child,
    );
  }
}
