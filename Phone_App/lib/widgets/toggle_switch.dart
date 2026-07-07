import 'package:flutter/material.dart';

import '../theme.dart';

/// Small animated on/off switch — shared visual language for every boolean
/// toggle in the app. Extracted from `alarm_screen.dart`'s previous
/// per-screen `_ToggleIndicator` so Settings' boolean rows (previously a
/// plain "ENABLED"/"DISABLED" text label) get the same real switch
/// affordance as Alarms.
class ToggleSwitch extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final indicator = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: value
            ? AppColors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(
          color: value ? AppColors.white60 : AppColors.white20,
          width: 0.8,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.white90 : AppColors.white20,
            ),
          ),
        ),
      ),
    );

    if (onChanged == null) {
      return Semantics(toggled: value, label: semanticLabel, child: indicator);
    }

    return Semantics(
      button: true,
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onChanged,
        behavior: HitTestBehavior.opaque,
        child: indicator,
      ),
    );
  }
}
