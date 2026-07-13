import 'package:flutter/material.dart';

import '../theme.dart';

/// Themed confirmation dialog, matching the app's existing `AlertDialog`
/// styling (see `alarm_screen.dart`'s label dialog). Used before
/// destructive or discard-changes actions so they're never a single
/// accidental tap away.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'CONFIRM',
  String cancelLabel = 'CANCEL',
  bool isDestructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: AppColors.white20),
      ),
      title: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelLG(color: AppColors.white90),
      ),
      content: Text(message, style: AppTextStyles.bodyLG(color: AppColors.white60)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            cancelLabel,
            style: AppTextStyles.labelSM(color: AppColors.white40),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: AppTextStyles.labelSM(
              color: isDestructive ? const Color(0xFFFF6B6B) : AppColors.white90,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
