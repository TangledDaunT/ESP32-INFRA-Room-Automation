import 'package:flutter/material.dart';

import '../theme.dart';

class DeviceButton extends StatelessWidget {
  const DeviceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isOn,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: isOn,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isOn ? AppColors.white10 : Colors.transparent,
            border: Border.all(
              color: isOn ? AppColors.white60 : AppColors.white20,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: isOn ? 1 : 0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Icon(
                    icon,
                    size: 28,
                    color: Color.lerp(
                      AppColors.white40,
                      AppColors.white90,
                      value,
                    ),
                    fill: value,
                    weight: 300 + (value * 100),
                    opticalSize: 24,
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTextStyles.labelLG(
                  color: isOn ? AppColors.white90 : AppColors.white40,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: isOn ? 32 : 0,
                height: 1,
                color: isOn ? AppColors.white90 : AppColors.white20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
