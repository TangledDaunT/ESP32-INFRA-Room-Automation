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
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTextStyles.labelLG(),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Flexible(child: trailing),
            ],
          ),
          const SizedBox(height: 2),
          Container(height: 1, color: AppColors.white20),
        ],
      ),
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
