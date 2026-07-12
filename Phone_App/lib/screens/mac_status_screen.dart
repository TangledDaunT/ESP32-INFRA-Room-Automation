import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/mac_agent_models.dart';
import '../providers/settings_provider.dart';
import '../services/mac_service.dart';
import '../services/page_activity_controller.dart';
import '../theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/speedometer_dial.dart';
import '../widgets/staggered_reveal.dart';

/// Dedicated Mac vitals page — CPU / memory / disk gauges, battery, wifi,
/// host info, and the agent's own tiny resource footprint.
///
/// Polls the Mac agent only while this exact page is the visible page in
/// the swipeable deck (and the app is foregrounded) — see
/// [PageActivityController] — so it costs nothing on the phone or the Mac
/// while the user is looking at any other page.
class MacStatusScreen extends StatefulWidget {
  const MacStatusScreen({super.key});

  @override
  State<MacStatusScreen> createState() => _MacStatusScreenState();
}

class _MacStatusScreenState extends State<MacStatusScreen> {
  static const _pollInterval = Duration(seconds: 5);
  static const _historyLength = 30;

  Timer? _pollTimer;
  PageActivityController? _activity;
  MacSystemStatus? _status;
  bool _loading = true;
  bool _refreshing = false;
  DateTime? _lastUpdated;
  String? _serviceBaseUrl;
  MacService? _service;

  final List<double> _cpuHistory = [];
  final List<double> _memHistory = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final baseUrl = context.read<SettingsProvider>().settings.macAgentBaseUrl;
    if (_serviceBaseUrl != baseUrl) {
      _serviceBaseUrl = baseUrl;
      _service = MacService(baseUrl);
    }
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

  void _handleVisibilityChange() {
    final visible = _activity?.isVisible(ControlPageIndex.macStatus) ?? false;
    if (visible) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _refresh();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final service = _service ??
        MacService(context.read<SettingsProvider>().settings.macAgentBaseUrl);
    final status = await service.fetchStatus();
    if (!mounted) {
      _refreshing = false;
      return;
    }
    setState(() {
      _status = status;
      _loading = false;
      _lastUpdated = DateTime.now();
      if (status != null) {
        _pushHistory(_cpuHistory, status.cpuPercent);
        _pushHistory(_memHistory, status.memoryPercent);
      }
    });
    _refreshing = false;
  }

  void _pushHistory(List<double> history, double value) {
    history.add(value);
    if (history.length > _historyLength) history.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final macAgentUrl =
      body: Stack(
        children: [
          const Positioned(
            top: -80,
            right: -50,
            child: _AmbientGlow(color: Color(0xFF1845FF)),
          ),
          const Positioned(
            bottom: -90,
            left: -60,
            child: _AmbientGlow(color: Color(0xFF1E8B62)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('MAC STATUS', style: AppTextStyles.labelLG(color: AppColors.white90)),
                      const SizedBox(width: 10),
                      _StatusDot(online: online),
                      const Spacer(),
                      Text(
                        macAgentUrl.replaceFirst(RegExp(r'^https?://'), ''),
                        style: AppTextStyles.labelSM(color: AppColors.white30),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _loading || _refreshing ? null : _refresh,
                        icon: AnimatedRotation(
                          turns: _refreshing ? 0.25 : 0,
                          duration: const Duration(milliseconds: 220),
                          child: const Icon(Symbols.refresh, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      child: _loading
                          ? const Center(
                              key: ValueKey('loading'),
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: AppColors.white60,
                              ),
                            )
                          : online
                              ? _buildBody(status!, key: const ValueKey('body'))
                              : _buildOffline(key: const ValueKey('offline')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _lastUpdated == null
                        ? 'Waiting for first update…'
                        : online
                            ? 'Updated ${TimeOfDay.fromDateTime(_lastUpdated!).format(context)}'
                            : 'Last checked ${TimeOfDay.fromDateTime(_lastUpdated!).format(context)}',
                    style: AppTextStyles.labelSM(color: AppColors.white30),
                  ),
                ],
              ),
            ),
          ),
        ],
                    ? 'Waiting for first update…'
                    : 'Updated ${TimeOfDay.fromDateTime(_lastUpdated!).format(context)}',
                style: AppTextStyles.labelSM(color: AppColors.white30),
              ),
  Widget _buildOffline({Key? key}) {
          ),
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.desktop_access_disabled, size: 36, color: AppColors.white20),
          const SizedBox(height: 12),
          Text('MAC AGENT UNREACHABLE', style: AppTextStyles.labelLG(color: AppColors.white30)),
        ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.desktop_access_disabled, size: 36, color: AppColors.white20),
  Widget _buildBody(MacSystemStatus status, {Key? key}) {
    return Column(
      key: key,
        ],
      ),
    );
  }
          child: StaggeredReveal(
            index: 0,
            child: Row(
              children: [
                Expanded(
                  child: SpeedometerDial(
                    value: status.cpuPercent,
                    maxValue: 100,
                    label: 'CPU',
                    icon: Symbols.memory,
                    unit: '%',
                    warningThreshold: 85,
                    statusColor: status.cpuPercent >= 85 ? const Color(0xFFFF6B6B) : null,
                  ),
                ),
                Expanded(
                  child: SpeedometerDial(
                    value: status.memoryPercent,
                    maxValue: 100,
                    label: 'MEMORY',
                    icon: Symbols.dns,
                    unit: '%',
                    warningThreshold: 90,
                    statusColor: status.memoryPercent >= 90 ? const Color(0xFFFF6B6B) : null,
                  ),
                ),
                Expanded(
                  child: SpeedometerDial(
                    value: status.diskPercent,
                    maxValue: 100,
                    label: 'DISK',
                    icon: Symbols.hard_drive,
                    unit: '%',
                    warningThreshold: 90,
                    statusColor: status.diskPercent >= 90 ? const Color(0xFFFF6B6B) : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 3,
          child: StaggeredReveal(
            index: 1,
            child: GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(14),
              child: _SparklineRow(cpuHistory: _cpuHistory, memHistory: _memHistory),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: StaggeredReveal(
            index: 2,
            child: Row(
              children: [
                _StatChip(
                  label: 'BATTERY',
                  value: status.batteryPercent == null
                      ? '--'
                      : '${status.batteryPercent!.round()}%${status.batteryCharging == true ? ' ⚡' : ''}',
                ),
                const SizedBox(width: 10),
                _StatChip(label: 'WIFI', value: status.wifiSsid ?? 'NO LINK'),
                const SizedBox(width: 10),
                _StatChip(label: 'UPTIME', value: _formatUptime(status.uptimeSeconds)),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    label: 'AGENT FOOTPRINT',
                    value: _formatAgentFootprint(status),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (status.hostname != null || status.macosVersion != null) ...[
          const SizedBox(height: 8),
          StaggeredReveal(
            index: 3,
            child: Text(
              [
                if (status.hostname != null) status.hostname!,
                if (status.macosVersion != null) 'macOS ${status.macosVersion}',
              ].join('  ·  '),
              style: AppTextStyles.labelSM(color: AppColors.white30),
            ),
          ),
        ],
      ],
    );
  }

  String _formatUptime(double? seconds) {
    if (seconds == null) return '--';
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  String _formatAgentFootprint(MacSystemStatus status) {
    if (status.agentCpuPercent == null && status.agentMemoryMb == null) {
      return '--';
    }
    final cpu = status.agentCpuPercent?.toStringAsFixed(1) ?? '--';
    final mem = status.agentMemoryMb?.round().toString() ?? '--';
    return '$cpu% CPU · ${mem}MB';
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), Colors.transparent],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
      return '--';
    }
    final cpu = status.agentCpuPercent?.toStringAsFixed(1) ?? '--';
    final mem = status.agentMemoryMb?.round().toString() ?? '--';
    return '$cpu% CPU · ${mem}MB';
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF4ADE80) : const Color(0xFFEF4444);
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6)],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.labelSM(color: AppColors.white30)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLG(color: AppColors.white90),
          ),
        ],
      ),
    );
  }
}

class _SparklineRow extends StatelessWidget {
  const _SparklineRow({required this.cpuHistory, required this.memHistory});

  final List<double> cpuHistory;
  final List<double> memHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Sparkline(
            label: 'CPU HISTORY',
            values: cpuHistory,
            color: const Color(0xFF1A6FFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Sparkline(
            label: 'MEMORY HISTORY',
            values: memHistory,
            color: const Color(0xFF44DD88),
          ),
        ),
      ],
    );
  }
}

/// Lightweight in-memory rolling history chart — a plain [CustomPainter],
/// no charting dependency, consistent with [SpeedometerDial]'s approach.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.label, required this.values, required this.color});

  final String label;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSM(color: AppColors.white30)),
        const SizedBox(height: 6),
        Expanded(
          child: CustomPaint(
            painter: _SparklinePainter(values: values, color: color),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = AppColors.white08
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), track);

    if (values.length < 2) return;

    final path = Path();
    final stepX = size.width / (values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final fraction = (values[i] / 100).clamp(0.0, 1.0);
      final point = Offset(i * stepX, size.height - fraction * size.height);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final lastFraction = (values.last / 100).clamp(0.0, 1.0);
    final lastPoint = Offset(size.width, size.height - lastFraction * size.height);
    canvas.drawCircle(lastPoint, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values.length != values.length ||
      (values.isNotEmpty && oldDelegate.values.isNotEmpty && oldDelegate.values.last != values.last);
}
