import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// The one big floating mic: tap to start talking, tap again to stop. While
/// listening it turns red with a stop square and rings ripple out with the
/// child's voice.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.listening,
    required this.level,
    required this.onTap,
    this.size = 112,
    this.enabled = true,
    this.idleLabel = 'Tap to talk',
  });

  final bool listening;
  final double level;
  final VoidCallback onTap;
  final double size;
  final bool enabled;
  final String idleLabel;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late final _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final color = !widget.enabled ? const Color(0xFFBDB6CF) : (widget.listening ? Gj.kumkum : Gj.saffron);
    final label = !widget.enabled
        ? 'Wait a moment...'
        : widget.listening
        ? 'Listening... tap to stop'
        : widget.idleLabel;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: widget.enabled
                ? (_) {
                    setState(() => _pressed = false);
                    HapticFeedback.mediumImpact();
                    widget.onTap();
                  }
                : null,
            child: RepaintBoundary(
              child: SizedBox.square(
                dimension: s * 1.45,
                child: AnimatedBuilder(
                  animation: _ripple,
                  builder: (context, child) => CustomPaint(
                    painter: _RingsPainter(
                      t: _ripple.value,
                      listening: widget.listening,
                      level: widget.level,
                      radius: s / 2,
                    ),
                    child: child,
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: _pressed ? 0.9 : (widget.listening ? 1.06 : 1),
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: s,
                        height: s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.4),
                            colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                          ),
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: [
                            BoxShadow(color: Gj.edge(color), offset: const Offset(0, 7)),
                            BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: widget.listening
                              ? Icon(
                                  Icons.stop_rounded,
                                  key: const ValueKey('stop'),
                                  color: Colors.white,
                                  size: s * 0.52,
                                )
                              : Icon(
                                  Icons.mic_rounded,
                                  key: const ValueKey('mic'),
                                  color: Colors.white,
                                  size: s * 0.56,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: widget.listening ? Gj.kumkum : Gj.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.t, required this.listening, required this.level, required this.radius});
  final double t, level, radius;
  final bool listening;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (listening) {
      for (var i = 0; i < 3; i++) {
        final p = (t + i / 3) % 1;
        final r = radius * (1 + p * (0.25 + level * 0.3));
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7 * (1 - p) + 1
            ..color = Gj.festive[i * 2].withValues(alpha: (1 - p) * 0.8),
        );
      }
    } else {
      // A slow breathing glow that says "tap me".
      final b = 0.5 + 0.5 * sin(t * 2 * pi);
      canvas.drawCircle(c, radius * (1.08 + 0.07 * b), Paint()..color = Gj.marigold.withValues(alpha: 0.18 + 0.15 * b));
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t || old.listening != listening || old.level != level;
}
