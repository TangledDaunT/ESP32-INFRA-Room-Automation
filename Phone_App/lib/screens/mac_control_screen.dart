import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/mac_service.dart';
import '../theme.dart';

class MacControlScreen extends StatefulWidget {
  const MacControlScreen({super.key});

  @override
  State<MacControlScreen> createState() => _MacControlScreenState();
}

class _MacControlScreenState extends State<MacControlScreen> {
  static const _targets = [
    _MacTarget(
      'vscode',
      'VS Code',
      Symbols.code_blocks,
      assetPath: 'icons/visual-studio-code-icon.webp',
    ),
    _MacTarget(
      'claude',
      'Claude',
      Symbols.psychology,
      assetPath: 'icons/claude-ai.jpg',
    ),
    _MacTarget(
      'codex',
      'Codex',
      Symbols.terminal,
      assetPath: 'icons/codex.png',
    ),
    _MacTarget(
      'chrome',
      'Chrome',
      Symbols.public,
      assetPath: 'icons/152759.png',
    ),
    _MacTarget(
      'whatsapp',
      'WhatsApp',
      Symbols.chat,
      assetPath: 'icons/images.jpeg',
    ),
    _MacTarget('openclaw', 'OpenClaw', Symbols.smart_toy),
  ];

  Timer? _idleTimer;
  String? _loadingTarget;
  String? _successTarget;
  String? _failureTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetIdleTimer());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final timeoutSeconds =
        context.read<SettingsProvider>().settings.idleTimeoutSeconds;
    _idleTimer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _activate(_MacTarget target) async {
    if (_loadingTarget != null) return;
    _resetIdleTimer();

    setState(() {
      _loadingTarget = target.id;
      _successTarget = null;
      _failureTarget = null;
    });

    final settings = context.read<SettingsProvider>().settings;
    final result =
        await MacService(settings.macAgentBaseUrl).activate(target.id);

    if (!mounted) return;
    setState(() {
      _loadingTarget = null;
      _successTarget = result.success ? target.id : null;
      _failureTarget = result.success ? null : target.id;
    });

    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        if (_successTarget == target.id) _successTarget = null;
        if (_failureTarget == target.id) _failureTarget = null;
      });
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.reason ?? 'MAC AGENT ERROR'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final macAgentUrl =
        context.watch<SettingsProvider>().settings.macAgentBaseUrl;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: GestureDetector(
        onTapDown: (_) => _resetIdleTimer(),
        onPanDown: (_) => _resetIdleTimer(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            const _LiquidBackdrop(),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'MAC CONTROL',
                          style:
                              AppTextStyles.labelLG(color: AppColors.white90),
                        ),
                        const Spacer(),
                        const Icon(
                          Symbols.swipe,
                          size: 18,
                          color: AppColors.white30,
                          weight: 300,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          macAgentUrl.replaceFirst(RegExp(r'^https?://'), ''),
                          style: AppTextStyles.labelSM(
                            color: AppColors.white30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        _HeaderIconButton(
                          tooltip: 'MAC settings',
                          icon: Symbols.settings,
                          onTap: () {
                            _resetIdleTimer();
                            Navigator.of(context).pushNamed('/settings');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.75,
                        ),
                        itemCount: _targets.length,
                        itemBuilder: (context, index) {
                          final target = _targets[index];
                          return _MacGlassButton(
                            target: target,
                            isLoading: _loadingTarget == target.id,
                            isSuccess: _successTarget == target.id,
                            isFailure: _failureTarget == target.id,
                            onTap: () => _activate(target),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacGlassButton extends StatefulWidget {
  const _MacGlassButton({
    required this.target,
    required this.isLoading,
    required this.isSuccess,
    required this.isFailure,
    required this.onTap,
  });

  final _MacTarget target;
  final bool isLoading;
  final bool isSuccess;
  final bool isFailure;
  final VoidCallback onTap;

  @override
  State<_MacGlassButton> createState() => _MacGlassButtonState();
}

class _MacGlassButtonState extends State<_MacGlassButton> {
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
      label: widget.target.label,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          scale: _pressed ? 1.035 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(
                      alpha: active || failed ? 0.18 : 0.06),
                  blurRadius: active || failed ? 34 : 18,
                  spreadRadius: active || failed ? 2 : 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: AppColors.white.withValues(
                      alpha: active ? 0.15 : 0.08,
                    ),
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
                              : _MacTargetIcon(
                                  target: widget.target,
                                  isSuccess: widget.isSuccess,
                                  isFailure: failed,
                                  active: active,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.target.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelLG(
                            color: AppColors.white90,
                          ).copyWith(letterSpacing: 2.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.18),
                width: 0.7,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.white60,
              fill: 0,
              weight: 300,
              opticalSize: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _MacTargetIcon extends StatelessWidget {
  const _MacTargetIcon({
    required this.target,
    required this.isSuccess,
    required this.isFailure,
    required this.active,
  });

  final _MacTarget target;
  final bool isSuccess;
  final bool isFailure;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (isSuccess || isFailure || target.assetPath == null) {
      return Icon(
        isSuccess
            ? Symbols.check
            : isFailure
                ? Symbols.close
                : target.icon,
        size: 28,
        color: isFailure ? const Color(0xFFFF9D9D) : AppColors.white90,
        fill: active ? 1 : 0,
        weight: active ? 450 : 300,
      );
    }

    return ClipOval(
      child: Image.asset(
        target.assetPath!,
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Icon(
          target.icon,
          size: 28,
          color: AppColors.white90,
          fill: active ? 1 : 0,
          weight: active ? 450 : 300,
        ),
      ),
    );
  }
}

class _LiquidBackdrop extends StatelessWidget {
  const _LiquidBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF030406),
                Color(0xFF090D12),
                Color(0xFF020203),
              ],
              stops: [0, 0.52, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.white.withValues(alpha: 0.055),
                Colors.transparent,
                AppColors.white.withValues(alpha: 0.025),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MacTarget {
  const _MacTarget(
    this.id,
    this.label,
    this.icon, {
    this.assetPath,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? assetPath;
}
