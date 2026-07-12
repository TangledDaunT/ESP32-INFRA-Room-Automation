import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/mac_agent_models.dart';
import '../providers/settings_provider.dart';
import '../services/mac_service.dart';
import '../services/page_activity_controller.dart';
import '../theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/staggered_reveal.dart';

class MacMediaScreen extends StatefulWidget {
  const MacMediaScreen({super.key});

  @override
  State<MacMediaScreen> createState() => _MacMediaScreenState();
}

class _MacMediaScreenState extends State<MacMediaScreen> {
  Timer? _pollTimer;
  bool _loading = true;
  bool _busy = false;
  MacSystemStatus? _status;
  List<MacNotificationItem> _notifications = const [];
  String? _previewBase64;
  String? _lastSavedPath;
  String? _message;

  PageActivityController? _activity;
  bool _everVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activity = context.read<PageActivityController>();
    if (!identical(_activity, activity)) {
      _activity?.removeListener(_handleVisibilityChange);
      _activity = activity;
      _activity!.addListener(_handleVisibilityChange);
      _handleVisibilityChange();
    }
  }

  @override
  void dispose() {
    _activity?.removeListener(_handleVisibilityChange);
    _pollTimer?.cancel();
    super.dispose();
  }

  // Poll only while this exact page is the one visible in the swipeable
  // deck (and the app is foregrounded) — see PageActivityController.
  void _handleVisibilityChange() {
    final visible = _activity?.isVisible(ControlPageIndex.macHub) ?? false;
    if (visible) {
      _pollTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
        _refresh(silent: true);
      });
      _refresh(silent: _everVisible);
      _everVisible = true;
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    final service = MacService(
      context.read<SettingsProvider>().settings.macAgentBaseUrl,
    );
    try {
      final results = await Future.wait([
        service.fetchStatus(),
        service.fetchNotifications(),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as MacSystemStatus?;
        _notifications = results[1] as List<MacNotificationItem>;
        _loading = false;
        if (!silent) {
          _message = 'Refreshed at ${TimeOfDay.now().format(context)}';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureScreenshot() async {
    await _runBusy(() async {
      final service = MacService(
        context.read<SettingsProvider>().settings.macAgentBaseUrl,
      );
      final result = await service.takeScreenshot();
      if (!mounted || result == null) return;
      setState(() {
        _previewBase64 = result.previewBase64;
        _lastSavedPath = result.savedTo;
        _message = result.reason ?? 'Screenshot saved';
      });
    });
  }

  Future<void> _recordScreen() async {
    await _runBusy(() async {
      final service = MacService(
        context.read<SettingsProvider>().settings.macAgentBaseUrl,
      );
      final result = await service.recordScreen(durationSeconds: 10);
      if (!mounted || result == null) return;
      setState(() {
        _previewBase64 = result.previewBase64;
        _lastSavedPath = result.savedTo;
        _message = result.reason ?? 'Screen recording saved';
      });
    });
  }

  Future<void> _dismissNotification(String id) async {
    await _runBusy(() async {
      final service = MacService(
        context.read<SettingsProvider>().settings.macAgentBaseUrl,
      );
      await service.dismissNotification(id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.where((item) => item.id != id).toList();
      });
    });
  }

  Future<void> _openNotification(String id) async {
    await _runBusy(() async {
      final service = MacService(
        context.read<SettingsProvider>().settings.macAgentBaseUrl,
      );
      final success = await service.openNotification(id);
      if (!mounted) return;
      setState(() {
        _message = success ? 'Notification action sent' : 'Action failed';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final macAgentUrl =
        context.watch<SettingsProvider>().settings.macAgentBaseUrl;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('MAC HUB',
                      style: AppTextStyles.labelLG(color: AppColors.white90)),
                  const Spacer(),
                  Text(
                    macAgentUrl.replaceFirst(RegExp(r'^https?://'), ''),
                    style: AppTextStyles.labelSM(color: AppColors.white30),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _loading ? null : () => _refresh(),
                    icon: const Icon(Symbols.refresh, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildNotificationsCard()),
                          const SizedBox(width: 14),
                          Expanded(child: _buildCaptureCard()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(_message!,
                    style: AppTextStyles.labelSM(color: AppColors.white40)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _status;
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _StatusChip(
              label: 'AGENT',
              value: status?.reachable == true ? 'ONLINE' : 'OFFLINE'),
          const SizedBox(width: 12),
          _StatusChip(
              label: 'BATTERY',
              value: status?.batteryPercent == null
                  ? '--'
                  : '${status!.batteryPercent!.round()}%'),
          const SizedBox(width: 12),
          _StatusChip(label: 'WIFI', value: status?.wifiSsid ?? 'NO LINK'),
          const SizedBox(width: 12),
          _StatusChip(
              label: 'CPU',
              value: '${(status?.cpuPercent ?? 0).toStringAsFixed(1)}%'),
          const SizedBox(width: 12),
          _StatusChip(
              label: 'MEM',
              value: '${(status?.memoryPercent ?? 0).toStringAsFixed(1)}%'),
          const SizedBox(width: 12),
          _StatusChip(
              label: 'DISK',
              value: '${(status?.diskPercent ?? 0).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('NOTIFICATIONS',
                  style: AppTextStyles.labelLG(color: AppColors.white90)),
              const Spacer(),
              Text('${_notifications.length}',
                  style: AppTextStyles.labelSM(color: AppColors.white30)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _notifications.isEmpty
                ? Center(
                    child: Text('No mirrored notifications',
                        style: AppTextStyles.bodyLG(color: AppColors.white30)),
                  )
                : ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      return StaggeredReveal(
                        index: index,
                        child: GlassContainer(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.appName,
                                        style: AppTextStyles.bodyLG(
                                            color: AppColors.white90)),
                                    const SizedBox(height: 4),
                                    Text(item.summary,
                                        style: AppTextStyles.labelSM(
                                            color: AppColors.white40)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Open app',
                                onPressed: _busy
                                    ? null
                                    : () => _openNotification(item.id),
                                icon: const Icon(Symbols.open_in_new, size: 18),
                              ),
                              IconButton(
                                tooltip: 'Dismiss',
                                onPressed: _busy
                                    ? null
                                    : () => _dismissNotification(item.id),
                                icon: const Icon(Symbols.close, size: 18),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureCard() {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CAPTURE',
              style: AppTextStyles.labelLG(color: AppColors.white90)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'SCREENSHOT',
                  icon: Symbols.photo_camera,
                  onTap: _busy ? null : _captureScreenshot,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'RECORD 10S',
                  icon: Symbols.videocam,
                  onTap: _busy ? null : _recordScreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: GlassDecoration.panel(borderRadius: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _previewBase64 == null
                    ? Center(
                        child: Text('Preview appears here',
                            style: AppTextStyles.labelSM(
                                color: AppColors.white30)),
                      )
                    : Image.memory(
                        base64Decode(_previewBase64!),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _lastSavedPath ?? 'Saves to Pictures / Movies / OpenClaw Remote',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSM(color: AppColors.white30),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSM(color: AppColors.white30)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyLG(color: AppColors.white90)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.white90),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSM(color: AppColors.white90),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
