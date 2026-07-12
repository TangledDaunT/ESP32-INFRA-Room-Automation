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
  MacService? _service;
  String? _serviceBaseUrl;
  MacSystemStatus? _status;
  DateTime? _lastUpdated;
  bool _loading = true;
  bool _refreshing = false;

  final List<double> _cpuHistory = [];
  final List<double> _memHistory = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final baseUrl = context.watch<SettingsProvider>().settings.macAgentBaseUrl;
    if (_serviceBaseUrl != baseUrl) {
      _serviceBaseUrl = baseUrl;
      _service = MacService(baseUrl);
      _cpuHistory.clear();
      _memHistory.clear();
      _status = null;
      _loading = true;
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
    unawaited(_refresh());
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;

    final status =
        await (_service ?? MacService(_serviceBaseUrl ?? '')).fetchStatus();
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
    history.add(value.clamp(0, 100).toDouble());
    if (history.length > _historyLength) history.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final macAgentUrl =
        context.watch<SettingsProvider>().settings.macAgentBaseUrl;
    final status = _status;
    final online = status?.reachable == true;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                online: online,
                baseUrl: macAgentUrl,
                loading: _loading,
                refreshing: _refreshing,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _loading
                      ? const _LoadingState(key: ValueKey('loading'))
                      : online && status != null
                          ? _StatusBody(
                              key: const ValueKey('status-body'),
                              status: status,
                              cpuHistory: _cpuHistory,
                              memHistory: _memHistory,
                            )
                          : const _OfflineState(key: ValueKey('offline')),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _lastUpdated == null
                    ? 'Waiting for first update'
                    : online
                        ? 'Updated ${TimeOfDay.fromDateTime(_lastUpdated!).format(context)}'
                        : 'Last checked ${TimeOfDay.fromDateTime(_lastUpdated!).format(context)}',
                style: AppTextStyles.labelSM(color: AppColors.white30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.online,
    required this.baseUrl,
    required this.loading,
    required this.refreshing,
    required this.onRefresh,
  });

  final bool online;
  final String baseUrl;
  final bool loading;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final shortUrl = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return Row(
      children: [
        Text(
          'MAC STATUS',
          style: AppTextStyles.labelLG(color: AppColors.white90),
        ),
        const SizedBox(width: 10),
        _StatusDot(online: online),
        const Spacer(),
        Flexible(
          child: Text(
            shortUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTextStyles.labelSM(color: AppColors.white30),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: 36,
          child: IconButton(
            tooltip: 'Refresh status',
            onPressed: loading || refreshing ? null : onRefresh,
            icon: AnimatedRotation(
              turns: refreshing ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(Symbols.refresh, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 26,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          color: AppColors.white60,
        ),
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.desktop_access_disabled,
              size: 36,
              color: AppColors.white20,
            ),
            const SizedBox(height: 12),
            Text(
              'MAC AGENT UNREACHABLE',
              style: AppTextStyles.labelLG(color: AppColors.white40),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    super.key,
    required this.status,
    required this.cpuHistory,
    required this.memHistory,
  });

  final MacSystemStatus status;
  final List<double> cpuHistory;
  final List<double> memHistory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 340;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: compact ? 5 : 6,
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
                        statusColor: status.cpuPercent >= 85
                            ? const Color(0xFFFF6B6B)
                            : null,
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
                        statusColor: status.memoryPercent >= 90
                            ? const Color(0xFFFF6B6B)
                            : null,
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
                        statusColor: status.diskPercent >= 90
                            ? const Color(0xFFFF6B6B)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: compact ? 2 : 3,
              child: StaggeredReveal(
                index: 1,
                child: GlassContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(14),
                  child: _SparklineRow(
                    cpuHistory: cpuHistory,
                    memHistory: memHistory,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: compact ? 58 : 66,
              child: StaggeredReveal(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        label: 'BATTERY',
                        value: _formatBattery(status),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        label: 'WIFI',
                        value:
                            status.wifiSsid ?? status.wifiDevice ?? 'NO LINK',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        label: 'UPTIME',
                        value: _formatUptime(status.uptimeSeconds),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        label: 'AGENT',
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
                    if (status.macosVersion != null)
                      'macOS ${status.macosVersion}',
                  ].join(' / '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSM(color: AppColors.white30),
                ),
              ),
            ],
          ],
        );

        if (!compact) return content;
        return SingleChildScrollView(
          child: SizedBox(height: 330, child: content),
        );
      },
    );
  }

  static String _formatBattery(MacSystemStatus status) {
    final battery = status.batteryPercent;
    if (battery == null) return '--';
    final suffix = status.batteryCharging == true ? ' CHG' : '';
    return '${battery.round()}%$suffix';
  }

  static String _formatUptime(double? seconds) {
    if (seconds == null) return '--';
    final duration = Duration(seconds: seconds.round());
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  static String _formatAgentFootprint(MacSystemStatus status) {
    if (status.agentCpuPercent == null && status.agentMemoryMb == null) {
      return '--';
    }
    final cpu = status.agentCpuPercent?.toStringAsFixed(1) ?? '--';
    final mem = status.agentMemoryMb?.round().toString() ?? '--';
    return '$cpu% / ${mem}MB';
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF4ADE80) : const Color(0xFFEF4444);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
        ],
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
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSM(color: AppColors.white30),
          ),
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
  const _SparklineRow({
    required this.cpuHistory,
    required this.memHistory,
  });

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

class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSM(color: AppColors.white30),
        ),
        const SizedBox(height: 8),
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
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = AppColors.white08
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baseline,
    );

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
    final lastPoint =
        Offset(size.width, size.height - lastFraction * size.height);
    canvas.drawCircle(lastPoint, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values.length != values.length ||
        (values.isNotEmpty &&
            oldDelegate.values.isNotEmpty &&
            oldDelegate.values.last != values.last);
  }
}
