import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../models/room_features.dart';
import '../providers/device_provider.dart';
import '../services/room_feature_service.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/glass_container.dart';

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
            backgroundColor: AppColors.black,
            body: SafeArea(
                child: Padding(
              padding: AppSpace.pagePadding,
              child: Column(children: [
                Row(children: [
                  GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('← COMMAND CENTER',
                          style:
                              AppTextStyles.labelLG(color: AppColors.white90))),
                  const Spacer(),
                  const Icon(Symbols.auto_awesome, color: AppColors.white60)
                ]),
                const SizedBox(height: 18),
                const TabBar(isScrollable: true, tabs: [
                  Tab(text: 'SCENES'),
                  Tab(text: 'AUTOMATION'),
                  Tab(text: 'SAFETY'),
                  Tab(text: 'TIMELINE')
                ]),
                const SizedBox(height: 16),
                const Expanded(
                    child: TabBarView(children: [
                  _ScenesTab(),
                  _RulesTab(),
                  _SafetyTab(),
                  _TimelineTab()
                ])),
              ]),
            ))),
      );
}

class _ScenesTab extends StatelessWidget {
  const _ScenesTab();
  IconData _icon(String name) => switch (name) {
        'psychology' => Symbols.psychology,
        'movie' => Symbols.movie,
        'music_note' => Symbols.music_note,
        'bedtime' => Symbols.bedtime,
        'shield' => Symbols.shield,
        _ => Symbols.auto_awesome
      };
  @override
  Widget build(BuildContext context) {
    final features = context.watch<RoomFeatureService>();
    final device = context.read<DeviceProvider>();
    return Column(children: [
      Expanded(
          child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.05,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12),
              itemCount: features.scenes.length,
              itemBuilder: (_, i) {
                final scene = features.scenes[i];
                final color = Color(scene.color);
                return Semantics(
                    button: true,
                    label: 'Run ${scene.name} scene',
                    child: GestureDetector(
                        onTap: () async {
                          if (scene.isDangerous &&
                              !(await showConfirmDialog(context,
                                  title: 'RUN ${scene.name.toUpperCase()}?',
                                  message: 'This scene turns room outputs off.',
                                  confirmLabel: 'RUN'))) return;
                          device.applyScene(scene);
                        },
                        child: GlassContainer(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color.withValues(alpha: .18),
                                      boxShadow:
                                          GlassDecoration.glow(color: color)),
                                  child: Icon(_icon(scene.icon), color: color)),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(scene.name.toUpperCase(),
                                        style: AppTextStyles.labelLG(
                                            color: AppColors.white90)),
                                    const SizedBox(height: 6),
                                    Text(
                                        '${scene.rgbBrightness}/255 • ${scene.fadeMs}ms',
                                        style: AppTextStyles.labelSM())
                                  ]))
                            ]))));
              })),
      const SizedBox(height: 12),
      _HoldAction(
          label: 'EMERGENCY ALL OFF',
          icon: Symbols.power_settings_new,
          color: const Color(0xFFFF6B6B),
          onConfirmed: device.emergencyAllOff),
    ]);
  }
}

class _RulesTab extends StatelessWidget {
  const _RulesTab();
  @override
  Widget build(BuildContext context) {
    final features = context.watch<RoomFeatureService>();
    return Column(children: [
      Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
              onPressed: () {
                final scene = features.scenes.first;
                features.saveRule(AutomationRule(
                    id: 'lux-${DateTime.now().millisecondsSinceEpoch}',
                    name: 'Night ambience',
                    trigger: RuleTrigger.lowLux,
                    sceneId: scene.id,
                    value: 40));
              },
              icon: const Icon(Symbols.add),
              label: const Text('ADD LOW-LUX RULE'))),
      Expanded(
          child: features.rules.isEmpty
              ? Center(
                  child: Text('NO RULES YET\nADD A LOW-LUX ROUTINE TO START',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLG(color: AppColors.white40)))
              : ListView.separated(
                  itemCount: features.rules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final rule = features.rules[i];
                    final detail = switch (rule.trigger) {
                      RuleTrigger.lowLux => 'WHEN LUX ≤ ${rule.value.round()}',
                      RuleTrigger.presence => 'WHEN PRESENCE IS DETECTED',
                      RuleTrigger.smoke => 'WHEN SMOKE ≥ ${rule.value.round()}',
                      RuleTrigger.time =>
                        'AT ${Duration(minutes: rule.value.round())}',
                      _ => 'WHEN MAC FOCUS STARTS'
                    };
                    return GlassContainer(
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          const Icon(Symbols.account_tree),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(rule.name.toUpperCase(),
                                    style: AppTextStyles.labelLG(
                                        color: AppColors.white90)),
                                const SizedBox(height: 4),
                                Text('$detail → ${rule.sceneId.toUpperCase()}',
                                    style: AppTextStyles.labelSM())
                              ])),
                          Switch(
                              value: rule.enabled,
                              onChanged: (_) => features.toggleRule(rule))
                        ]));
                  }))
    ]);
  }
}

class _SafetyTab extends StatelessWidget {
  const _SafetyTab();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<DeviceProvider>().state;
    final settings = context.read<DeviceProvider>().settings;
    final ok = s.openclawOk && s.smokeValue < settings.smokeAlarmThreshold;
    return ListView(children: [
      _HealthCard(
          title: ok ? 'ROOM HEALTHY' : 'ATTENTION NEEDED',
          value: ok ? 'NOMINAL' : 'CHECK SYSTEM',
          color: ok ? const Color(0xFF34D399) : const Color(0xFFFB7185),
          icon: ok ? Symbols.verified : Symbols.warning),
      const SizedBox(height: 12),
      _HealthCard(
          title: 'AIR QUALITY',
          value:
              '${s.smokeValue.toStringAsFixed(0)} / ${settings.smokeAlarmThreshold.toStringAsFixed(0)} PPM',
          color:
              s.smokeAlarm ? const Color(0xFFFB7185) : const Color(0xFFFBBF24),
          icon: Symbols.detector_smoke),
      const SizedBox(height: 12),
      _HealthCard(
          title: 'ESP32 LINK',
          value: s.openclawOk ? 'CONNECTED' : 'OFFLINE',
          color:
              s.openclawOk ? const Color(0xFF34D399) : const Color(0xFFFB7185),
          icon: Symbols.wifi),
      const SizedBox(height: 12),
      _HealthCard(
          title: 'PRESENCE / LUX',
          value:
              '${s.presenceDetected ? 'OCCUPIED' : 'EMPTY'} • ${s.luxValue.toStringAsFixed(0)} LX',
          color: const Color(0xFF7DD3FC),
          icon: Symbols.sensors),
    ]);
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard(
      {required this.title,
      required this.value,
      required this.color,
      required this.icon});
  final String title, value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 18),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.labelLG(color: AppColors.white60)),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.headlineMD(color: color))
        ]))
      ]));
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab();
  @override
  Widget build(BuildContext context) {
    final values = context.watch<RoomFeatureService>().telemetry;
    if (values.isEmpty)
      return Center(
          child: Text('COLLECTING ROOM INTELLIGENCE…',
              style: AppTextStyles.labelLG(color: AppColors.white40)));
    final latest = values.first;
    final maxLux = values.map((e) => e.lux).fold(1.0, (a, b) => a > b ? a : b);
    return ListView(children: [
      Text('LAST ${values.length} ROOM SNAPSHOTS',
          style: AppTextStyles.labelLG(color: AppColors.white60)),
      const SizedBox(height: 16),
      SizedBox(
          height: 180,
          child: CustomPaint(
              painter: _TimelinePainter(
                  values.reversed.map((e) => e.lux / maxLux).toList()),
              child: const SizedBox.expand())),
      const SizedBox(height: 16),
      _HealthCard(
          title: 'LATEST SNAPSHOT',
          value:
              '${latest.lux.toStringAsFixed(0)} LX • ${latest.smoke.toStringAsFixed(0)} PPM • ${latest.present ? 'PRESENT' : 'AWAY'}',
          color: const Color(0xFF7DD3FC),
          icon: Symbols.timeline)
    ]);
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas c, Size s) {
    if (values.length < 2) return;
    final p = Paint()
      ..color = const Color(0xFF7DD3FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * s.width / (values.length - 1);
      final y = s.height - (values[i].clamp(0, 1) * s.height);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => old.values != values;
}

class _HoldAction extends StatefulWidget {
  const _HoldAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onConfirmed});
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onConfirmed;
  @override
  State<_HoldAction> createState() => _HoldActionState();
}

class _HoldActionState extends State<_HoldAction> {
  bool held = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
      onLongPress: () async {
        setState(() => held = true);
        await widget.onConfirmed();
        if (mounted) setState(() => held = false);
      },
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 58,
          decoration: BoxDecoration(
              color: widget.color.withValues(alpha: held ? .22 : .08),
              border: Border.all(color: widget.color.withValues(alpha: .7)),
              borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, color: widget.color),
            const SizedBox(width: 10),
            Text('HOLD: ${widget.label}',
                style: AppTextStyles.labelLG(color: widget.color))
          ])));
}
