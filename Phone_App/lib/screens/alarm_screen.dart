// lib/screens/alarm_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';
import '../theme.dart';
import '../widgets/time_picker_sheet.dart';

/// Alarm management screen — shows list of alarms, allows add/edit/delete/toggle.
class AlarmScreen extends StatelessWidget {
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Consumer<AlarmProvider>(
          builder: (context, alarmProvider, _) {
            final alarms = alarmProvider.alarms;

            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: AppSpace.pagePadding,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Header ──────────────────────────────
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              '← ALARMS',
                              style:
                                  AppTextStyles.labelLG(color: AppColors.white90),
                            ),
                          ),
                          const Spacer(),
                          // Add alarm button
                          GestureDetector(
                            onTap: () => _addAlarm(context, alarmProvider),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Symbols.add,
                                    size: 16,
                                    color: AppColors.white60,
                                    weight: 300,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ADD',
                                    style: AppTextStyles.labelSM(
                                        color: AppColors.white60),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpace.lg),
                      const Divider(
                          color: AppColors.white20, thickness: 1, height: 1),
                      const SizedBox(height: AppSpace.xl),

                      if (alarms.isEmpty) ...[
                        // ── Empty state ──────────────────────
                        const SizedBox(height: 60),
                        Center(
                          child: Column(
                            children: [
                              const Icon(
                                Symbols.alarm_off,
                                size: 36,
                                color: AppColors.white20,
                                fill: 0,
                                weight: 200,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'NO ALARMS SET',
                                style: AppTextStyles.labelLG(
                                    color: AppColors.white20),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap ADD to create your first alarm',
                                style: AppTextStyles.labelSM(
                                    color: AppColors.white20),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // ── Alarm list ───────────────────────
                        ...alarms.map((alarm) => _AlarmTile(
                              alarm: alarm,
                              onToggle: () =>
                                  alarmProvider.toggleAlarm(alarm.id),
                              onDelete: () =>
                                  alarmProvider.removeAlarm(alarm.id),
                              onEdit: () =>
                                  _editAlarm(context, alarmProvider, alarm),
                            )),
                      ],

                      const SizedBox(height: AppSpace.xxl),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addAlarm(BuildContext context, AlarmProvider provider) async {
    final now = TimeOfDay.now();
    final result = await showTimePickerSheet(
      context,
      title: 'NEW ALARM',
      initialTime: now,
    );
    if (result == null) return;

    // Show label input
    if (!context.mounted) return;
    final label = await _showLabelDialog(context, '');
    if (!context.mounted) return;

    final alarm = AlarmModel(
      id: '${result.hour}_${result.minute}_${DateTime.now().millisecondsSinceEpoch}',
      hour: result.hour,
      minute: result.minute,
      label: label ?? '',
      isEnabled: true,
    );
    await provider.addAlarm(alarm);
  }

  Future<void> _editAlarm(
    BuildContext context,
    AlarmProvider provider,
    AlarmModel alarm,
  ) async {
    final result = await showTimePickerSheet(
      context,
      title: 'EDIT ALARM',
      initialTime: TimeOfDay(hour: alarm.hour, minute: alarm.minute),
    );
    if (result == null) return;
    if (!context.mounted) return;

    final label = await _showLabelDialog(context, alarm.label);
    if (!context.mounted) return;

    await provider.updateAlarm(alarm.copyWith(
      hour: result.hour,
      minute: result.minute,
      label: label ?? alarm.label,
    ));
  }

  Future<String?> _showLabelDialog(BuildContext context, String initial) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.white20),
        ),
        title: Text('LABEL', style: AppTextStyles.labelLG(color: AppColors.white90)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.bodyLG(),
          cursorColor: AppColors.white90,
          cursorWidth: 1,
          decoration: InputDecoration(
            hintText: 'e.g. Morning, Work...',
            hintStyle: AppTextStyles.bodyLG(color: AppColors.white20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('SKIP',
                style: AppTextStyles.labelSM(color: AppColors.white40)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('SET',
                style: AppTextStyles.labelSM(color: AppColors.white90)),
          ),
        ],
      ),
    );
  }
}

// ── Alarm Tile ───────────────────────────────────────────────────────────────

class _AlarmTile extends StatelessWidget {
  const _AlarmTile({
    required this.alarm,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final AlarmModel alarm;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final active = alarm.isEnabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active
              ? AppColors.white.withValues(alpha: 0.04)
              : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.white20 : AppColors.white10,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            // ── Time display (tap to edit) ──────────────────
            Expanded(
              child: GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        alarm.timeString,
                        style: GoogleFonts.nunito(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppColors.white90
                              : AppColors.white20,
                          height: 1.0,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (alarm.label.isNotEmpty)
                            Text(
                              alarm.label.toUpperCase(),
                              style: AppTextStyles.labelSM(
                                color: active
                                    ? AppColors.white60
                                    : AppColors.white20,
                              ),
                            ),
                          Text(
                            active ? 'ACTIVE' : 'OFF',
                            style: AppTextStyles.labelSM(
                              color: active
                                  ? AppColors.white40
                                  : AppColors.white20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Icon(
                  Symbols.delete,
                  size: 18,
                  color: AppColors.white20,
                  fill: 0,
                  weight: 200,
                ),
              ),
            ),

            // ── Toggle switch ───────────────────────────────
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
                child: _ToggleIndicator(active: active),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleIndicator extends StatelessWidget {
  const _ToggleIndicator({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: active
            ? AppColors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(
          color: active ? AppColors.white60 : AppColors.white20,
          width: 0.8,
        ),
      ),
      child: Align(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.white90 : AppColors.white20,
            ),
          ),
        ),
      ),
    );
  }
}
