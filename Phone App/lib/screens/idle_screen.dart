// lib/screens/idle_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../providers/device_provider.dart';
import '../theme.dart';
import '../widgets/sensor_card.dart';

class IdleScreen extends StatefulWidget {
  final VoidCallback onWake;
  const IdleScreen({super.key, required this.onWake});

  @override
  State<IdleScreen> createState() => _IdleScreenState();
}

class _IdleScreenState extends State<IdleScreen>
    with TickerProviderStateMixin {
  late Timer _clockTimer;
  late AnimationController _fadeIn;
  late AnimationController _scanLine;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _fadeIn.dispose();
    _scanLine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final state = device.state;
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: widget.onWake,
      onPanDown: (_) => widget.onWake(),
      child: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          color: AppTheme.bg,
          child: Stack(
            children: [
              // ── Scan line effect ──────────────────────
              AnimatedBuilder(
                animation: _scanLine,
                builder: (_, __) => Positioned(
                  top: _scanLine.value * size.height - 2,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withOpacity(0),
                          AppTheme.accent.withOpacity(0.15),
                          AppTheme.accent.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Corner decorations ────────────────────
              _cornerDecor(Alignment.topLeft),
              _cornerDecor(Alignment.topRight, flip: true),
              _cornerDecor(Alignment.bottomLeft, flipV: true),
              _cornerDecor(Alignment.bottomRight, flip: true, flipV: true),

              // ── Main content ──────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // ── Time ────────────────────────────
                      Text(
                        DateFormat('hh:mm').format(_now),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 86,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      Text(
                        DateFormat('ss').format(_now),
                        style: TextStyle(
                          color: AppTheme.accent.withOpacity(0.6),
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 4,
                        ),
                      ),

                      // AM/PM
                      Text(
                        DateFormat('a').format(_now),
                        style: TextStyle(
                          color: AppTheme.textSecond,
                          fontSize: 14,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Date ────────────────────────────
                      Text(
                        DateFormat('EEEE, MMMM d yyyy').format(_now).toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),

                      const Spacer(flex: 1),

                      // ── Status bar ───────────────────────
                      _statusRow(state, device),

                      const SizedBox(height: 16),

                      // ── Sensor cards ──────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: SensorCard(
                              label: 'SMOKE / MQ-2',
                              value: state.smokeValue.toStringAsFixed(0),
                              unit: 'ppm',
                              icon: Icons.air,
                              color: state.smokeAlarm
                                  ? AppTheme.danger
                                  : AppTheme.accent,
                              alert: state.smokeAlarm,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SensorCard(
                              label: 'LUMINANCE',
                              value: state.luxValue.toStringAsFixed(1),
                              unit: 'lux',
                              icon: Icons.wb_sunny_outlined,
                              color: AppTheme.colorLight,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      PresenceCard(present: state.presenceDetected),

                      const SizedBox(height: 10),

                      // ── Sleep / Mode badge ────────────────
                      _modeBadge(state),

                      const Spacer(flex: 2),

                      // ── Tap hint ─────────────────────────
                      Text(
                        'TAP ANYWHERE TO CONTROL',
                        style: TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 9,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusRow(state, DeviceProvider device) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConnectionDot(label: 'MQTT', connected: state.mqttOk),
        const SizedBox(width: 16),
        ConnectionDot(label: 'BLE', connected: state.bleOk),
        const SizedBox(width: 16),
        ConnectionDot(label: 'OPENCLAW', connected: state.openclawOk),
      ],
    );
  }

  Widget _modeBadge(state) {
    String text;
    Color color;
    IconData icon;

    switch (state.sleepState) {
      case SleepState.sleeping:
        text = 'SLEEP MODE';
        color = AppTheme.accentDim;
        icon = Icons.bedtime;
        break;
      case SleepState.nightMode:
        text = 'NIGHT MODE';
        color = AppTheme.colorRgb.withOpacity(0.8);
        icon = Icons.nights_stay;
        break;
      case SleepState.wakingUp:
        text = 'WAKE-UP ROUTINE';
        color = AppTheme.colorLight;
        icon = Icons.wb_twilight;
        break;
      default:
        text = 'STANDBY';
        color = AppTheme.textDim;
        icon = Icons.radio_button_off;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _cornerDecor(Alignment alignment, {bool flip = false, bool flipV = false}) {
    return Align(
      alignment: alignment,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(flip ? -1 : 1, flipV ? -1 : 1, 1),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 30,
            height: 30,
            child: CustomPaint(painter: _CornerPainter()),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accent.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
