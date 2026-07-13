import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';

/// Reusable animated glass "launcher" button — icon/asset avatar + label,
/// with press-scale and optional loading/success/failure states.
///
/// Built directly on the app's glass decoration language (no
/// `BackdropFilter`/`ImageFilter.blur`) so it stays cheap to repaint on
/// low-power hardware — see `glass_container.dart` for why blur is
/// avoided. Replaces the previous per-screen `_MacGlassButton`.
class GlassActionButton extends StatefulWidget {
  const GlassActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.assetPath,
    this.isLoading = false,
    this.isSuccess = false,
    this.isFailure = false,
    this.semanticLabel,
    this.borderRadius = 28,
  });

  final IconData icon;
  final String label;
  final String? assetPath;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isLoading;
  final bool isSuccess;
  final bool isFailure;
  final String? semanticLabel;
  final double borderRadius;

  @override
  State<GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<GlassActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _pressed || widget.isLoading || widget.isSuccess;
    final failed = widget.isFailure;
    final glowColor = failed
        ? const Color(0xFFFF6B6B)
        : widget.isSuccess
            ? const Color(0xFF62F5C7)
            : AppColors.white;

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          duration: GlassDecoration.motionFast,
          curve: GlassDecoration.motionCurve,
          scale: _pressed ? 0.985 : 1,
          child: AnimatedContainer(
            duration: GlassDecoration.motionMedium,
            curve: GlassDecoration.motionCurve,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              color: AppColors.white.withValues(alpha: active ? 0.15 : 0.08),
              border: Border.all(
                color: glowColor.withValues(
                  alpha: active || failed ? 0.55 : 0.18,
                ),
                width: 0.8,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white.withValues(alpha: active ? 0.22 : 0.13),
                  AppColors.white.withValues(alpha: 0.035),
                  glowColor.withValues(alpha: active ? 0.11 : 0.04),
                ],
                stops: const [0, 0.55, 1],
              ),
              boxShadow: [
                ...GlassDecoration.depth(
                  isActive: active || failed,
                  pressed: _pressed,
                  color: glowColor,
                ),
                BoxShadow(
                  color: glowColor.withValues(
                    alpha: active || failed ? 0.18 : 0.06,
                  ),
                  blurRadius: active || failed ? 34 : 18,
                  spreadRadius: active || failed ? 2 : 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.18),
                      width: 0.7,
                    ),
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: AppColors.white90,
                            ),
                          )
                        : _GlassActionIcon(
                            icon: widget.icon,
                            assetPath: widget.assetPath,
                            isSuccess: widget.isSuccess,
                            isFailure: failed,
                            active: active,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLG(color: AppColors.white90)
                        .copyWith(letterSpacing: 2.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassActionIcon extends StatelessWidget {
  const _GlassActionIcon({
    required this.icon,
    required this.assetPath,
    required this.isSuccess,
    required this.isFailure,
    required this.active,
  });

  final IconData icon;
  final String? assetPath;
  final bool isSuccess;
  final bool isFailure;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (isSuccess || isFailure || assetPath == null) {
      return Icon(
        isSuccess
            ? Symbols.check
            : isFailure
                ? Symbols.close
                : icon,
        size: 28,
        color: isFailure ? const Color(0xFFFF9D9D) : AppColors.white90,
        fill: active ? 1 : 0,
        weight: active ? 450 : 300,
      );
    }

    return ClipOval(
      child: Image.asset(
        assetPath!,
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Icon(
          icon,
          size: 28,
          color: AppColors.white90,
          fill: active ? 1 : 0,
          weight: active ? 450 : 300,
        ),
      ),
    );
  }
}
