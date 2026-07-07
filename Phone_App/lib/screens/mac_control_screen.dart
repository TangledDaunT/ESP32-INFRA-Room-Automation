import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/mac_service.dart';
import '../services/page_activity_controller.dart';
import '../theme.dart';
import '../widgets/glass_action_button.dart';

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

  String? _loadingTarget;
  String? _successTarget;
  String? _failureTarget;

  void _pingActivity() => context.read<PageActivityController>().pingActivity();

  Future<void> _activate(_MacTarget target) async {
    if (_loadingTarget != null) return;
    _pingActivity();

    setState(() {
      _loadingTarget = target.id;
      _successTarget = null;
      _failureTarget = null;
    });

    final settings = context.read<SettingsProvider>().settings;
    final result = await MacService(settings.macAgentBaseUrl).open(target.id);

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

  Future<void> _close(_MacTarget target) async {
    if (_loadingTarget != null) return;
    _pingActivity();

    setState(() {
      _loadingTarget = target.id;
      _successTarget = null;
      _failureTarget = null;
    });

    final settings = context.read<SettingsProvider>().settings;
    final result = await MacService(settings.macAgentBaseUrl).close(target.id);

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

  Future<void> _openSettings() async {
    final activity = context.read<PageActivityController>();
    activity.pause();
    await Navigator.of(context).pushNamed('/settings');
    if (mounted) activity.resume();
  }

  @override
  Widget build(BuildContext context) {
    final macAgentUrl =
        context.watch<SettingsProvider>().settings.macAgentBaseUrl;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: GestureDetector(
        onTapDown: (_) => _pingActivity(),
        onPanDown: (_) => _pingActivity(),
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
                          onTap: _openSettings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to open, long-press to close',
                      style: AppTextStyles.labelSM(color: AppColors.white30),
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
                          return GlassActionButton(
                            icon: target.icon,
                            assetPath: target.assetPath,
                            label: target.label,
                            isLoading: _loadingTarget == target.id,
                            isSuccess: _successTarget == target.id,
                            isFailure: _failureTarget == target.id,
                            onTap: () => _activate(target),
                            onLongPress: () => _close(target),
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
