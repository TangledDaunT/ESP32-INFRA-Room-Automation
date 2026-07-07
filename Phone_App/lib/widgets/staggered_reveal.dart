import 'package:flutter/material.dart';

/// Wraps [child] with a subtle staggered fade + upward slide entrance.
///
/// Deliberately lightweight — no `AnimationController`/`vsync`, just a
/// one-shot delayed `setState` driving two implicit animations. It settles
/// after [duration] and repaints nothing further, so it costs nothing once
/// a list has finished revealing. Used to make list screens (Alarms,
/// Activity Log, Mac Hub notifications) feel alive without an ongoing
/// animation cost.
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    super.key,
    required this.index,
    required this.child,
    this.stepDelay = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 260),
  });

  final int index;
  final Widget child;
  final Duration stepDelay;
  final Duration duration;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Cap the stagger so a long list doesn't push later items' reveal out
    // by several seconds — items past this just reveal together.
    final steps = widget.index.clamp(0, 8);
    Future.delayed(widget.stepDelay * steps, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: widget.duration,
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}
