// lib/widgets/sensor_card.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool alert;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.color = AppTheme.accent,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = alert ? AppTheme.danger : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: alert ? AppTheme.dangerDim : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: displayColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: displayColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textSecond,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: displayColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        unit,
                        style: TextStyle(
                          color: displayColor.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (alert)
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: AppTheme.danger),
        ],
      ),
    );
  }
}

class PresenceCard extends StatefulWidget {
  final bool present;

  const PresenceCard({super.key, required this.present});

  @override
  State<PresenceCard> createState() => _PresenceCardState();
}

class _PresenceCardState extends State<PresenceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.present ? AppTheme.success : AppTheme.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: widget.present
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.6 * _pulse.value),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRESENCE',
                style: TextStyle(
                  color: AppTheme.textSecond,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.present ? 'DETECTED' : 'NONE',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConnectionDot extends StatelessWidget {
  final String label;
  final bool connected;

  const ConnectionDot({
    super.key,
    required this.label,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? AppTheme.success : AppTheme.textDim,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: connected ? AppTheme.success : AppTheme.textDim,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
