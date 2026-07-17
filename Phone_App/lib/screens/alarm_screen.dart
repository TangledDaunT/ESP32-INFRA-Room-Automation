// lib/screens/alarm_screen.dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/staggered_reveal.dart';
import '../widgets/time_picker_sheet.dart';
import '../widgets/toggle_switch.dart';

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
                              style: AppTextStyles.labelLG(
                                  color: AppColors.white90),
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
                        ...alarms
                            .asMap()
                            .entries
                            .map((entry) => StaggeredReveal(
                                  index: entry.key,
                                  child: _AlarmTile(
                                    alarm: entry.value,
                                    onToggle: () => alarmProvider
                                        .toggleAlarm(entry.value.id),
                                    onDelete: () => _deleteAlarm(
                                        context, alarmProvider, entry.value),
                                    onEdit: () => _editAlarm(
                                        context, alarmProvider, entry.value),
                                  ),
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
    final mission = await _pickMission(context, AlarmMission.gentleWake);
    if (!context.mounted) return;

    final alarm = AlarmModel(
      id: '${result.hour}_${result.minute}_${DateTime.now().millisecondsSinceEpoch}',
      hour: result.hour,
      minute: result.minute,
      label: label ?? '',
      isEnabled: true,
      mission: mission,
    );
    await provider.addAlarm(alarm);
  }

  Future<void> _deleteAlarm(
    BuildContext context,
    AlarmProvider provider,
    AlarmModel alarm,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'DELETE ALARM',
      message: alarm.label.isEmpty
          ? 'Delete the ${alarm.timeString} alarm?'
          : 'Delete "${alarm.label}" (${alarm.timeString})?',
      confirmLabel: 'DELETE',
    );
    if (confirmed) await provider.removeAlarm(alarm.id);
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
    final mission = await _pickMission(context, alarm.mission);
    if (!context.mounted) return;

    await provider.updateAlarm(alarm.copyWith(
      hour: result.hour,
      minute: result.minute,
      label: label ?? alarm.label,
      mission: mission,
    ));
  }

  Future<AlarmMission> _pickMission(
          BuildContext context, AlarmMission initial) async =>
      await showModalBottomSheet<AlarmMission>(
        context: context,
        backgroundColor: AppColors.black,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: AlarmMission.values
                    .map((mission) => ListTile(
                          title: Text(mission.name
                              .replaceAll(RegExp(r'([A-Z])'), r' $1')
                              .toUpperCase()),
                          trailing: mission == initial
                              ? const Icon(Symbols.check)
                              : null,
                          onTap: () => Navigator.pop(ctx, mission),
                        ))
                    .toList()),
          ),
        ),
      ) ??
      initial;

  Future<String?> _showLabelDialog(BuildContext context, String initial) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: AppColors.white20),
        ),
        title: Text('LABEL',
            style: AppTextStyles.labelLG(color: AppColors.white90)),
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
          borderRadius: BorderRadius.zero,
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
                        style: const TextStyle(fontFamily: 'Manrope').copyWith(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: active ? AppColors.white90 : AppColors.white20,
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

            Semantics(
              button: true,
              label: 'Delete alarm',
              child: GestureDetector(
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
            ),

            // ── Toggle switch ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
              child: ToggleSwitch(
                value: active,
                onChanged: onToggle,
                semanticLabel: 'Alarm enabled',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
