import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/activity_log_entry.dart';
import '../services/activity_log_service.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/staggered_reveal.dart';

Future<void> _confirmClear(BuildContext context, ActivityLogService log) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'CLEAR ACTIVITY LOG',
    message: 'This removes all recorded activity. This cannot be undone.',
    confirmLabel: 'CLEAR',
  );
  if (confirmed) log.clear();
}

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Consumer<ActivityLogService>(
          builder: (context, log, _) {
            final entries = log.entries;

            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: AppSpace.pagePadding,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              '← ACTIVITY',
                              style: AppTextStyles.labelLG(color: AppColors.white90),
                            ),
                          ),
                          const Spacer(),
                          Semantics(
                            button: true,
                            label: 'Clear activity log',
                            child: GestureDetector(
                              onTap: () => _confirmClear(context, log),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                children: [
                                  const Icon(
                                    Symbols.delete,
                                    size: 16,
                                    color: AppColors.white40,
                                    fill: 0,
                                    weight: 300,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CLEAR',
                                    style: AppTextStyles.labelSM(color: AppColors.white40),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),
                      const Divider(color: AppColors.white20, thickness: 1, height: 1),
                      const SizedBox(height: AppSpace.xl),
                      if (entries.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 64),
                            child: Text(
                              'NO ACTIVITY YET',
                              style: AppTextStyles.labelLG(color: AppColors.white20),
                            ),
                          ),
                        )
                      else
                        ...entries.asMap().entries.map((e) => StaggeredReveal(
                              index: e.key,
                              child: _LogTile(entry: e.value),
                            )),
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
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final ActivityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.type) {
      ActivityLogType.command => AppColors.white90,
      ActivityLogType.alarm => const Color(0xFFFF6B6B),
      ActivityLogType.automation => const Color(0xFF7DD3FC),
      ActivityLogType.sensor => const Color(0xFFFBBF24),
      ActivityLogType.system => AppColors.white60,
    };

    final time = TimeOfDay.fromDateTime(entry.timestamp).format(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.white20, width: 0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.title.toUpperCase(),
                        style: AppTextStyles.labelLG(color: color),
                      ),
                      const Spacer(),
                      Text(
                        time,
                        style: AppTextStyles.labelSM(color: AppColors.white40),
                      ),
                    ],
                  ),
                  if (entry.detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      entry.detail,
                      style: AppTextStyles.bodyLG(color: AppColors.white60),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
