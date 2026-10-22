import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The home backdrop: an Uttarayan sky with a turning sun and drifting
/// clouds, over the white salt desert of the Rann with bhunga huts of Kutch
/// on the horizon.
class SkyScene extends StatefulWidget {
  const SkyScene({super.key, required this.child});
  final Widget child;

  @override
  State<SkyScene> createState() => _SkySceneState();
}

class _SkySceneState extends State<SkyScene> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => CustomPaint(painter: _SkyPainter(_clock.value)),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * 0.8;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Gj.skyTop, Gj.skyMid, Gj.skyLow],
          stops: [0, 0.55, 0.8],
        ).createShader(Offset.zero & size),
    );

    // Sun with slowly turning rays.
    final sun = Offset(w * 0.84, h * 0.09);
    canvas.save();
    canvas.translate(sun.dx, sun.dy);
    canvas.rotate(t * 2 * pi);
    final ray = Paint()..color = const Color(0x55FFD54F);
    for (var i = 0; i < 12; i++) {
      canvas.rotate(pi / 6);
      canvas.drawPath(
        Path()
          ..moveTo(-9, 40)
          ..lineTo(0, 74)
          ..lineTo(9, 40)
          ..close(),
        ray,
      );
    }
    canvas.restore();
    canvas.drawCircle(sun, 38, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawCircle(sun, 30, Paint()..color = const Color(0xFFFFE57F));

    // Clouds drifting left to right, wrapping round.
    for (final (i, y, s) in [(0, 0.16, 1.0), (1, 0.34, 0.7), (2, 0.5, 0.85), (3, 0.26, 0.55)]) {
      final speed = 0.6 + i * 0.25;
      final x = ((t * speed + i * 0.29) % 1.3 - 0.15) * w;
      _cloud(canvas, Offset(x, h * y), 60 * s);
    }

    // Distant bhunga huts on the horizon.
    final hut = Paint()..color = const Color(0xFFE7C9A0);
    final roof = Paint()..color = const Color(0xFFB0703A);
    for (final (fx, sc) in [(0.12, 1.0), (0.2, 0.75), (0.68, 0.9), (0.77, 0.65)]) {
      final base = Offset(w * fx, horizon + 4);
      final r = 15 * sc;
      canvas.drawRect(Rect.fromLTWH(base.dx - r, base.dy - r * 1.3, r * 2, r * 1.3), hut);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - r * 1.35, base.dy - r * 1.2)
          ..lineTo(base.dx, base.dy - r * 2.7)
          ..lineTo(base.dx + r * 1.35, base.dy - r * 1.2)
          ..close(),
        roof,
      );
      canvas.drawRect(Rect.fromLTWH(base.dx - r * 0.25, base.dy - r * 0.8, r * 0.5, r * 0.8), roof);
    }

    // The white Rann, gently rolling, with its honeycomb of salt.
    final ground = Path()
      ..moveTo(0, horizon)
      ..quadraticBezierTo(w * 0.3, horizon - 18, w * 0.55, horizon + 2)
      ..quadraticBezierTo(w * 0.8, horizon + 18, w, horizon - 6)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ground, Paint()..color = Gj.salt);
    canvas.save();
    canvas.clipPath(ground);
    final hex = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFD9E3EC);
    const r = 22.0;
    for (var row = 0; horizon + row * r * 1.5 < h + r; row++) {
      for (var col = -1; col * r * 1.74 < w + r; col++) {
        final c = Offset(col * r * 1.74 + (row.isOdd ? r * 0.87 : 0), horizon + row * r * 1.5);
        final p = Path();
        for (var k = 0; k < 6; k++) {
          final a = pi / 6 + k * pi / 3;
          final pt = c + Offset(cos(a), sin(a)) * r;
          k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(p..close(), hex);
      }
    }
    canvas.restore();
  }

  void _cloud(Canvas canvas, Offset c, double s) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, s * 0.15), width: s * 2.4, height: s * 0.8), p);
    canvas.drawCircle(c + Offset(-s * 0.45, 0), s * 0.42, p);
    canvas.drawCircle(c + Offset(s * 0.15, -s * 0.18), s * 0.55, p);
    canvas.drawCircle(c + Offset(s * 0.7, s * 0.02), s * 0.36, p);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t;
}

/// An Uttarayan kite with a patola-style split, a bow tail and a string.
class KitePainter extends CustomPainter {
  KitePainter({required this.color, required this.accent, this.sway = 0, this.glow = 0});
  final Color color, accent;

  /// -1 to 1: how far the tail swings.
  final double sway;

  /// 0 to 1: a soft halo, for today's kite.
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final kiteH = w * 1.05;
    final top = Offset(w / 2, 0);
    final left = Offset(0, kiteH * 0.42);
    final right = Offset(w, kiteH * 0.42);
    final bottom = Offset(w / 2, kiteH);
    final center = Offset(w / 2, kiteH * 0.42);

    // String trailing down out of the picture.
    canvas.drawPath(
      Path()
        ..moveTo(bottom.dx, bottom.dy)
        ..cubicTo(bottom.dx + 20 * sway, bottom.dy + 40, bottom.dx - 30, size.height - 40, bottom.dx + 10 * sway, size.height),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x99FFFFFF),
    );

    if (glow > 0) {
      canvas.drawCircle(center, w * 0.85, Paint()..color = Colors.white.withValues(alpha: 0.35 * glow));
    }

    final kite = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawShadow(kite, Colors.black38, 4, false);
    canvas.drawPath(kite, Paint()..color = color);
    // Two opposite panels in the accent, like a patola diamond.
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(center.dx, center.dy)
        ..close(),
      Paint()..color = accent,
    );
    canvas.drawPath(
      Path()
        ..moveTo(bottom.dx, bottom.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(center.dx, center.dy)
        ..close(),
      Paint()..color = accent,
    );
    // Centre diamond.
    final d = w * 0.14;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - d)
        ..lineTo(center.dx + d, center.dy)
        ..lineTo(center.dx, center.dy + d)
        ..lineTo(center.dx - d, center.dy)
        ..close(),
      Paint()..color = Colors.white,
    );
    // Spars.
    final spar = Paint()
      ..color = const Color(0x664A2A10)
      ..strokeWidth = 2;
    canvas.drawLine(top, bottom, spar);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(center.dx, center.dy - w * 0.22, right.dx, right.dy),
      spar..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      kite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );

    // Little tail flap at the bottom.
    canvas.drawPath(
      Path()
        ..moveTo(bottom.dx, bottom.dy - 4)
        ..lineTo(bottom.dx - w * 0.14, bottom.dy + w * 0.16)
        ..lineTo(bottom.dx + w * 0.14, bottom.dy + w * 0.16)
        ..close(),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(KitePainter old) =>
      old.sway != sway || old.glow != glow || old.color != color || old.accent != accent;
}

/// A kite that bobs on the breeze, with a label tag.
class FlyingKite extends StatefulWidget {
  const FlyingKite({
    super.key,
    required this.width,
    required this.color,
    required this.accent,
    required this.child,
    this.phase = 0,
    this.glow = false,
    this.onTap,
  });

  final double width;
  final Color color, accent;

  /// Drawn in the middle of the kite (a +, a number...).
  final Widget child;
  final double phase;
  final bool glow;
  final VoidCallback? onTap;

  @override
  State<FlyingKite> createState() => _FlyingKiteState();
}

class _FlyingKiteState extends State<FlyingKite> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final a = (_c.value + widget.phase) * 2 * pi;
          return Transform.translate(
            offset: Offset(sin(a) * 5, cos(a * 2) * 4),
            child: Transform.rotate(angle: sin(a) * 0.08, child: child),
          );
        },
        child: SizedBox(
          width: w,
          height: w * 1.6,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    painter: KitePainter(
                      color: widget.color,
                      accent: widget.accent,
                      sway: sin((_c.value + widget.phase) * 2 * pi),
                      glow: widget.glow ? 0.6 + 0.4 * sin(_c.value * 4 * pi) : 0,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: w * 1.05 * 0.42 - w * 0.2,
                height: w * 0.4,
                child: Center(
                  child: Container(
                    width: w * 0.4,
                    height: w * 0.4,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.accent, width: max(2, w * 0.025)),
                    ),
                    child: FittedBox(child: Padding(padding: const EdgeInsets.all(2), child: widget.child)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
