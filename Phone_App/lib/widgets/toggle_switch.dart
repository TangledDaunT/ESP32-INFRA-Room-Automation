import 'package:flutter/material.dart';

import '../theme.dart';

/// Small animated on/off switch — shared visual language for every boolean
/// toggle in the app. Extracted from `alarm_screen.dart`'s previous
/// per-screen `_ToggleIndicator` so Settings' boolean rows (previously a
/// plain "ENABLED"/"DISABLED" text label) get the same real switch
/// affordance as Alarms.
class ToggleSwitch extends StatefulWidget {
  const ToggleSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final VoidCallback? onChanged;
  final String? semanticLabel;

  @override
  State<ToggleSwitch> createState() => _ToggleSwitchState();
}

class _ToggleSwitchState extends State<ToggleSwitch> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final indicator = AnimatedScale(
      duration: GlassDecoration.motionFast,
      curve: GlassDecoration.motionCurve,
      scale: _pressed ? 0.96 : 1,
      child: AnimatedContainer(
        duration: GlassDecoration.motionMedium,
        curve: GlassDecoration.motionCurve,
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: widget.value
              ? AppColors.white.withValues(alpha: 0.16)
              : AppColors.white.withValues(alpha: 0.035),
          border: Border.all(
            color: widget.value ? AppColors.white60 : AppColors.white20,
            width: 0.8,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.white.withValues(alpha: widget.value ? 0.18 : 0.07),
              Colors.transparent,
            ],
          ),
          boxShadow: GlassDecoration.depth(
            isActive: widget.value,
            pressed: _pressed,
          ),
        ),
        child: AnimatedAlign(
          duration: GlassDecoration.motionMedium,
          curve: GlassDecoration.motionCurve,
          alignment:
              widget.value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: GlassDecoration.motionMedium,
              curve: GlassDecoration.motionCurve,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.value ? AppColors.white90 : AppColors.white20,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                  if (widget.value)
                    BoxShadow(
                      color: AppColors.white.withValues(alpha: 0.22),
                      blurRadius: 12,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.onChanged == null) {
      return Semantics(
        toggled: widget.value,
        label: widget.semanticLabel,
        child: indicator,
      );
    }

    return Semantics(
      button: true,
      toggled: widget.value,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onChanged,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: indicator,
      ),
    );
  }
}
