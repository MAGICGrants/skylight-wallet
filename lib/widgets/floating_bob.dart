import 'package:flutter/material.dart';

/// Gently bobs its [child] up and down on a slow loop — a drifting-cloud effect
/// for the logo on the welcome / unlock screens.
class FloatingBob extends StatefulWidget {
  final Widget child;

  /// Peak vertical travel from centre, in logical pixels.
  final double amplitude;

  /// Time for one full up-and-down cycle.
  final Duration period;

  const FloatingBob({
    super.key,
    required this.child,
    this.amplitude = 7,
    this.period = const Duration(seconds: 4),
  });

  @override
  State<FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<FloatingBob> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  late final Animation<double> _anim = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      // Oscillate around the rest position: -amplitude → +amplitude.
      builder: (_, child) => Transform.translate(
        offset: Offset(0, (_anim.value - 0.5) * 2 * widget.amplitude),
        child: child,
      ),
      child: widget.child,
    );
  }
}
