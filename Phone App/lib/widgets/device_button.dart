import 'package:flutter/material.dart';

import '../theme.dart';

/// Icon-only relay toggle button with liquid-glass aesthetic.
///
/// ON state: brighter icon, subtle white glow, highlighted glass container.
/// OFF state: dimmed icon, minimal glass container.
class DeviceButton extends StatelessWidget {
  const DeviceButton({
    super.key,
    required this.icon,
    required this.isOn,
    required this.onTap,
    this.semanticLabel,
  });

  /// Material Symbol icon for this relay.
  final IconData icon;

  /// Whether the relay is currently on.
  final bool isOn;

  /// Called when the button is tapped.
  final VoidCallback onTap;

  /// Accessibility label (e.g. "Fan", "Light").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: isOn,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: GlassDecoration.panel(
            borderRadius: 14,
            isActive: isOn,
          ).copyWith(
            boxShadow: isOn ? GlassDecoration.glow(blur: 16) : null,
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isOn ? 1 : 0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return Icon(
                  icon,
                  size: 28,
                  color: Color.lerp(
                    AppColors.white20,
                    AppColors.white90,
                    value,
                  ),
                  fill: value,
                  weight: 200 + (value * 200),
                  opticalSize: 24,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
