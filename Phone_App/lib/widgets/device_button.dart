import 'package:flutter/material.dart';

import '../theme.dart';

/// Icon-only relay toggle button with liquid-glass aesthetic.
///
/// ON state: brighter icon, subtle white glow, highlighted glass container.
/// OFF state: dimmed icon, minimal glass container.
class DeviceButton extends StatefulWidget {
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
  State<DeviceButton> createState() => _DeviceButtonState();
}

class _DeviceButtonState extends State<DeviceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: widget.isOn,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          duration: GlassDecoration.motionFast,
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.975 : 1,
          child: AnimatedContainer(
            duration: GlassDecoration.motionMedium,
            curve: GlassDecoration.motionCurve,
            decoration: GlassDecoration.panel(
              borderRadius: 16,
              isActive: widget.isOn,
              pressed: _pressed,
            ),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: widget.isOn ? 1 : 0),
                duration: GlassDecoration.motionMedium,
                curve: GlassDecoration.motionCurve,
                builder: (context, value, _) {
                  return Icon(
                    widget.icon,
                    size: 29,
                    color: Color.lerp(
                      AppColors.white20,
                      AppColors.white90,
                      value,
                    ),
                    fill: value,
                    weight: 220 + (value * 210),
                    opticalSize: 24,
                    shadows: widget.isOn
                        ? [
                            Shadow(
                              color: AppColors.white.withValues(alpha: 0.22),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
