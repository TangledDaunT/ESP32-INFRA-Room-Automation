import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../services/page_activity_controller.dart';
import '../theme.dart';

/// Secondary dashboard page for infrequent controls. Keeping these actions
/// out of Home leaves the live device controls readable at a glance.
class HomeToolsScreen extends StatelessWidget {
  const HomeToolsScreen({super.key});

  Future<void> _open(BuildContext context, String route) async {
    final activity = context.read<PageActivityController>();
    activity.pause();
    await Navigator.of(context).pushNamed(route);
    if (context.mounted) activity.resume();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: AppSpace.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOME UTILITIES',
                style: AppTextStyles.labelLG(color: AppColors.white90)
                    .copyWith(fontSize: 13, letterSpacing: 2),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'SWIPE RIGHT TO RETURN HOME',
                style: AppTextStyles.labelSM(color: AppColors.white40),
              ),
              const SizedBox(height: AppSpace.lg),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpace.md,
                  crossAxisSpacing: AppSpace.md,
                  childAspectRatio: 2.2,
                  children: [
                    _ToolTile(
                      icon: Symbols.auto_awesome,
                      label: 'COMMAND CENTER',
                      description: 'SCENES, SAFETY, RULES',
                      onTap: () => _open(context, '/command_center'),
                    ),
                    _ToolTile(
                      icon: Symbols.motion_photos_on,
                      label: 'MOTION',
                      description: 'CAMERA MONITORING',
                      onTap: () => _open(context, '/motion_feed'),
                    ),
                    _ToolTile(
                      icon: Symbols.settings,
                      label: 'SETTINGS',
                      description: 'APP AND DEVICE',
                      onTap: () => _open(context, '/settings'),
                    ),
                    _ToolTile(
                      icon: Symbols.alarm,
                      label: 'ALARMS',
                      description: 'SCHEDULES AND WAKE-UP',
                      onTap: () => _open(context, '/alarms'),
                    ),
                    _ToolTile(
                      icon: Symbols.history,
                      label: 'LOGS',
                      description: 'ACTIVITY HISTORY',
                      onTap: () => _open(context, '/activity'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolTile extends StatefulWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: GlassDecoration.motionFast,
          decoration: GlassDecoration.panel(pressed: _pressed),
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Icon(widget.icon, size: 34, color: AppColors.white90),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: AppTextStyles.labelLG(color: AppColors.white90)
                          .copyWith(fontSize: 13, letterSpacing: 1.8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description,
                      style: AppTextStyles.labelSM(color: AppColors.white60)
                          .copyWith(letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              const Icon(Symbols.chevron_right, color: AppColors.white40),
            ],
          ),
        ),
      ),
    );
  }
}
