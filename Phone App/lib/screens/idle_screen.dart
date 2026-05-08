import 'dart:async';


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/device_state.dart';
import '../providers/device_provider.dart';

/// Apple StandBy-inspired OLED clock screen.
///
/// Layout (landscape):
///
///   ┌──────────────────────────────────────────────── [●●●] ┐
///   │                                                        │
///   │               W E D N E S D A Y                       │
///   │                                                        │
///   │              09    ●●    48                           │
///   │                                                        │
///   │                  ─────────                            │
///   │               7  May  2026                            │
///   │                                                        │
///   └────────────────────────────────────────────────────────┘
///
/// Animations:
///   • Colon dots: smooth opacity fade 0.20 → 1.0, sine-eased, 1 s period
///   • Ambient glow bloom: slow radial pulse behind clock, 4 s period
///   • Day text: very slow breathing opacity 0.35 → 0.60, 6 s period
///
/// Behavioural contracts (unchanged):
///   - Tap anywhere → Navigator.of(context).pushNamed('/control')
///   - _navigating guard prevents double-push
///   - Landscape + WakeLock managed globally in main.dart
class IdleScreen extends StatefulWidget {
  const IdleScreen({super.key});

  @override
  State<IdleScreen> createState() => _IdleScreenState();
}

class _IdleScreenState extends State<IdleScreen>
    with TickerProviderStateMixin {
  // ── Clock tick ─────────────────────────────────────────────
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _navigating = false;

  // ── Animation controllers ───────────────────────────────────
  late final AnimationController _colonCtrl;   // 1 s, fades colon
  late final AnimationController _glowCtrl;    // 4 s, pulses bloom
  late final AnimationController _dayCtrl;     // 6 s, breathes day label

  late final Animation<double> _colonOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _dayOpacity;

  // ── Palette ─────────────────────────────────────────────────
  /// Electric blue accent — clock digits, colon, glow.
  static const Color _blue = Color(0xFF1A6FFF);

  /// Lighter highlight for digit text-shadow.
  static const Color _blueGlow = Color(0xFF4D8FFF);

  @override
  void initState() {
    super.initState();

    // Clock: tick every second.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Colon blink — forward + reverse = 1 full cycle per 2 s (0.5 Hz).
    // easeInOut gives a smooth sine-like feel, not a hard flash.
    _colonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _colonOpacity = CurvedAnimation(
      parent: _colonCtrl,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 0.18, end: 1.0));

    // Ambient glow pulse — slow, barely perceptible bloom.
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowOpacity = CurvedAnimation(
      parent: _glowCtrl,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 0.04, end: 0.13));

    // Day label breathing — very gentle, emphasises the typography.
    _dayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _dayOpacity = CurvedAnimation(
      parent: _dayCtrl,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 0.30, end: 0.60));
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _colonCtrl.dispose();
    _glowCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  /// Tap anywhere → control screen. Guard prevents stacked pushes.
  Future<void> _wakeToControl() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    await Navigator.of(context).pushNamed('/control');
    if (mounted) setState(() => _navigating = false);
  }

  // ────────────────────────────────────────────────────────────
  // Widgets
  // ────────────────────────────────────────────────────────────

  /// Ambient radial bloom — a soft blue cloud centred behind the clock.
  Widget _buildGlowBloom(double size) {
    return AnimatedBuilder(
      animation: _glowOpacity,
      builder: (_, __) => Container(
        width: size * 2.4,
        height: size * 0.9,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(size),
          gradient: RadialGradient(
            colors: [
              _blue.withValues(alpha: _glowOpacity.value),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }

  /// Two vertically-stacked circles as the colon separator.
  /// Their opacity is driven by [_colonOpacity].
  Widget _buildColon(double clockFontSize) {
    final dotSize = (clockFontSize * 0.040).clamp(14.0, 24.0);
    final gap = dotSize * 0.65;
    final hPad = (clockFontSize * 0.022).clamp(8.0, 20.0);

    return AnimatedBuilder(
      animation: _colonOpacity,
      builder: (_, __) => Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Opacity(
          opacity: _colonOpacity.value,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(dotSize),
              SizedBox(height: gap),
              _dot(dotSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _blue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _blueGlow.withValues(alpha: 0.55),
              blurRadius: size * 1.2,
              spreadRadius: size * 0.1,
            ),
          ],
        ),
      );

  /// Clock digit text with a soft glow shadow.
  Widget _buildDigit(String text, TextStyle style) {
    return Text(
      text,
      style: style.copyWith(
        shadows: [
          Shadow(
            color: _blueGlow.withValues(alpha: 0.50),
            blurRadius: 32,
          ),
          Shadow(
            color: _blue.withValues(alpha: 0.25),
            blurRadius: 64,
          ),
        ],
      ),
    );
  }

  /// Day of week in wide-spaced ultra-light caps.
  Widget _buildDayLabel(String dayText, double screenHeight) {
    return AnimatedBuilder(
      animation: _dayOpacity,
      builder: (_, __) => Opacity(
        opacity: _dayOpacity.value,
        child: Text(
          dayText,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w200,
            fontSize: (screenHeight * 0.042).clamp(14.0, 28.0),
            color: Colors.white,
            letterSpacing: (screenHeight * 0.016).clamp(6.0, 16.0),
            height: 1.0,
          ),
        ),
      ),
    );
  }

  /// Thin horizontal rule that acts as a visual separator.
  Widget _buildDivider(double width) => Container(
        width: width,
        height: 0.5,
        color: Colors.white.withValues(alpha: 0.18),
      );

  /// Date row: day-number · month · year, styled with weight contrast.
  Widget _buildDateRow(DateTime now, double screenHeight) {
    final dayNum = DateFormat('d').format(now);          // "7"
    final monthName = DateFormat('MMMM').format(now);   // "May"
    final year = DateFormat('yyyy').format(now);         // "2026"

    final baseSize = (screenHeight * 0.052).clamp(16.0, 32.0);

    TextStyle numStyle() => GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: baseSize,
          color: Colors.white.withValues(alpha: 0.88),
          height: 1.0,
        );

    TextStyle monthStyle() => GoogleFonts.nunito(
          fontWeight: FontWeight.w300,
          fontSize: baseSize,
          color: Colors.white.withValues(alpha: 0.65),
          letterSpacing: 1.5,
          height: 1.0,
        );

    TextStyle yearStyle() => GoogleFonts.nunito(
          fontWeight: FontWeight.w200,
          fontSize: baseSize * 0.80,
          color: Colors.white.withValues(alpha: 0.35),
          letterSpacing: 2.0,
          height: 1.0,
        );

    // Separator dot between elements
    Widget sep() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: GoogleFonts.nunito(
              fontSize: baseSize,
              fontWeight: FontWeight.w200,
              color: Colors.white.withValues(alpha: 0.22),
              height: 1.0,
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(dayNum, style: numStyle()),
        sep(),
        Text(monthName.toUpperCase(), style: monthStyle()),
        sep(),
        Text(year, style: yearStyle()),
      ],
    );
  }

  /// Three connection status dots — MQTT · BLE · HTTP.
  Widget _buildConnectionDots(DeviceState s) {
    Color statusColor(ConnectionStatus status) =>
        status == ConnectionStatus.connected
            ? const Color(0xFF4ADE80)
            : const Color(0xFFEF4444);

    Widget dot(ConnectionStatus status, String label) => Tooltip(
          message: label,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor(status),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor(status).withValues(alpha: 0.55),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(s.mqttStatus, 'MQTT'),
        const SizedBox(width: 6),
        dot(s.bleStatus, 'BLE'),
        const SizedBox(width: 6),
        dot(s.openclawStatus, 'HTTP'),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final deviceState = context.watch<DeviceProvider>().state;
    final size = MediaQuery.of(context).size;

    // In landscape the short side is the height.
    final screenHeight = size.height;

    // Clock digits: 68% of landscape height for dramatic impact.
    final clockFontSize = (screenHeight * 0.68).clamp(110.0, 500.0);

    final hourText = DateFormat('HH').format(_now);
    final minText = DateFormat('mm').format(_now);
    // Full day name in uppercase spaced caps.
    final dayText = DateFormat('EEEE').format(_now).toUpperCase();

    final clockStyle = GoogleFonts.nunito(
      fontWeight: FontWeight.w900,
      fontSize: clockFontSize,
      color: _blue,
      height: 1.0,
      letterSpacing: -1,
    );

    // Width of divider — approx width of the two digit groups + colon.
    final dividerWidth = (screenHeight * 0.55).clamp(100.0, 360.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _wakeToControl,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ── Ambient glow bloom, centred ─────────────────
            Center(
              child: _buildGlowBloom(clockFontSize),
            ),

            // ── Main content column, centred ─────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Day of week
                  _buildDayLabel(dayText, screenHeight),

                  SizedBox(height: screenHeight * 0.012),

                  // Clock: HH  ●●  mm
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildDigit(hourText, clockStyle),
                      _buildColon(clockFontSize),
                      _buildDigit(minText, clockStyle),
                    ],
                  ),

                  SizedBox(height: screenHeight * 0.018),

                  // Thin separator
                  _buildDivider(dividerWidth),

                  SizedBox(height: screenHeight * 0.022),

                  // Date row
                  _buildDateRow(_now, screenHeight),
                ],
              ),
            ),

            // ── Connection dots — top-right ─────────────────
            Positioned(
              top: 14,
              right: 18,
              child: _buildConnectionDots(deviceState),
            ),
          ],
        ),
      ),
    );
  }
}
