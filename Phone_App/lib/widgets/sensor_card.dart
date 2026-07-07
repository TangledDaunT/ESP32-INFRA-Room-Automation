import 'package:flutter/material.dart';

import '../theme.dart';

class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final resolvedValueStyle =
        valueStyle ?? AppTextStyles.tabular(AppTextStyles.headlineMD());

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.white60,
          fill: 0,
          weight: 300,
          opticalSize: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.labelLG(),
          ),
        ),
        Text(
          value,
          style: resolvedValueStyle,
          textAlign: TextAlign.right,
        ),
        if (unit != null && unit!.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            unit!.toUpperCase(),
            style: AppTextStyles.labelSM(),
          ),
        ],
      ],
    );
  }
}

class ConnectionStatusBars extends StatelessWidget {
  const ConnectionStatusBars({
    super.key,
    required this.activeCount,
  });

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isActive = index < activeCount;
        return Padding(
          padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
          child: Container(
            width: 1,
            height: 10,
            color: isActive ? AppColors.white90 : AppColors.white20,
          ),
        );
      }),
    );
  }
}
