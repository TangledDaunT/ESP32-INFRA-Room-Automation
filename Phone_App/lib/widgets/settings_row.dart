import 'package:flutter/material.dart';

import '../theme.dart';

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label.toUpperCase(),
      style: AppTextStyles.labelLG(color: AppColors.white90).copyWith(
        fontSize: 12,
        letterSpacing: 1.1,
      ),
    );

    final row = LayoutBuilder(
      builder: (context, constraints) {
        // Stacking narrow rows prevents labels and credentials from competing
        // for the same horizontal space on phones or with large text enabled.
        final compact = constraints.maxWidth < 480;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                labelWidget,
                const SizedBox(height: AppSpace.sm),
                Align(alignment: Alignment.centerRight, child: trailing),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: labelWidget),
                    const SizedBox(width: AppSpace.md),
                    Flexible(child: trailing),
                  ],
                ),
              const SizedBox(height: AppSpace.sm),
              Container(height: 1, color: AppColors.white20),
            ],
          ),
        );
      },
    );

    if (onTap == null) {
      return row;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}
