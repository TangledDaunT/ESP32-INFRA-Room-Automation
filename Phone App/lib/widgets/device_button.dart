// lib/widgets/device_button.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class DeviceButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isOn;
  final Color color;
  final VoidCallback onTap;

  const DeviceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isOn,
    required this.color,
    required this.onTap,
  });

  @override
  State<DeviceButton> createState() => _DeviceButtonState();
}

class _DeviceButtonState extends State<DeviceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (_, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isOn
                ? widget.color.withOpacity(0.12)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isOn
                  ? widget.color.withOpacity(0.6 * _glowAnim.value)
                  : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: widget.isOn
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.25 * _glowAnim.value),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 32,
                color: widget.isOn ? widget.color : AppTheme.textDim,
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isOn ? widget.color : AppTheme.textSecond,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isOn ? widget.color : AppTheme.textDim,
                  boxShadow: widget.isOn
                      ? [BoxShadow(color: widget.color, blurRadius: 4)]
                      : [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
