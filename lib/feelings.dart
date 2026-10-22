import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// How the child felt about a moment. Picking one gets Sheru asking "why?",
/// to practise "I felt ... because ...".
enum Feeling {
  happy('happy', Gj.marigold),
  excited('excited', Gj.saffron),
  surprised('surprised', Gj.lilac),
  calm('calm', Gj.teal),
  tired('tired', Gj.peacock),
  sad('sad', Gj.inkSoft);

  const Feeling(this.word, this.color);
  final String word;
  final Color color;

  static Feeling? byName(String? name) => values.where((f) => f.name == name).firstOrNull;

  String get why => 'Why did you feel $word? Say: I felt $word because...';
}

/// The five senses, for describing a moment rather than just naming it.
enum Sense {
  see('See', Icons.visibility_rounded, Gj.peacock, 'What could you see? What colours and shapes?'),
  hear('Hear', Icons.hearing_rounded, Gj.lilac, 'What could you hear? Birds? Music? The wind?'),
  smell('Smell', Icons.local_florist_rounded, Gj.kumkum, 'What could you smell? Was it nice?'),
  touch('Touch', Icons.back_hand_rounded, Gj.saffron, 'What did you touch? Was it soft, rough or bumpy?'),
  taste('Taste', Icons.icecream_rounded, Gj.leaf, 'Did you taste something? Was it sweet, salty or spicy?');

  const Sense(this.label, this.icon, this.color, this.question);
  final String label;
  final IconData icon;
  final Color color;
  final String question;
}

/// A round cartoon face for a feeling, drawn rather than an emoji so it looks
/// the same on every phone and in exports.
class FeelingFace extends StatelessWidget {
  const FeelingFace(this.feeling, {super.key, this.size = 48});
  final Feeling feeling;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: FacePainter(feeling));
}

class FacePainter extends CustomPainter {
  FacePainter(this.feeling);
  final Feeling feeling;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = s / 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(feeling.color, Colors.white, 0.35)!, feeling.color],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ink = Paint()
      ..color = Gj.ink
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = Gj.ink;
    final eyeY = c.dy - r * 0.18;
    final eyeDx = r * 0.32;
    final mouthY = c.dy + r * 0.28;
    final w = r * 0.42;

    void eyes({double open = 1}) {
      for (final x in [c.dx - eyeDx, c.dx + eyeDx]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, eyeY), width: r * 0.16, height: r * 0.24 * open), dot);
      }
    }

    void smile(double depth) {
      final path = Path()
        ..moveTo(c.dx - w, mouthY - depth * 0.3)
        ..quadraticBezierTo(c.dx, mouthY + depth, c.dx + w, mouthY - depth * 0.3);
      canvas.drawPath(path, ink);
    }

    switch (feeling) {
      case Feeling.happy:
        eyes();
        smile(r * 0.32);
      case Feeling.excited:
        // Star eyes and a big open grin.
        for (final x in [c.dx - eyeDx, c.dx + eyeDx]) {
          canvas.drawPath(_star(Offset(x, eyeY), r * 0.17), dot);
        }
        final grin = Path()
          ..moveTo(c.dx - w, mouthY - r * 0.06)
          ..quadraticBezierTo(c.dx, mouthY + r * 0.55, c.dx + w, mouthY - r * 0.06)
          ..close();
        canvas.drawPath(grin, dot);
      case Feeling.surprised:
        eyes(open: 1.3);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, mouthY + r * 0.05), width: r * 0.3, height: r * 0.38), dot);
      case Feeling.calm:
        // Closed, smiling eyes.
        for (final x in [c.dx - eyeDx, c.dx + eyeDx]) {
          canvas.drawArc(Rect.fromCenter(center: Offset(x, eyeY), width: r * 0.3, height: r * 0.22), pi, pi, false, ink);
        }
        smile(r * 0.18);
      case Feeling.tired:
        for (final x in [c.dx - eyeDx, c.dx + eyeDx]) {
          canvas.drawLine(Offset(x - r * 0.13, eyeY), Offset(x + r * 0.13, eyeY), ink);
        }
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, mouthY + r * 0.08), width: r * 0.22, height: r * 0.18), dot);
        final z = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(fontFamily: fontFamily, fontSize: r * 0.5, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        z.paint(canvas, Offset(c.dx + r * 0.4, c.dy - r * 0.85));
      case Feeling.sad:
        eyes();
        final frown = Path()
          ..moveTo(c.dx - w * 0.8, mouthY + r * 0.12)
          ..quadraticBezierTo(c.dx, mouthY - r * 0.2, c.dx + w * 0.8, mouthY + r * 0.12);
        canvas.drawPath(frown, ink);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(c.dx + eyeDx + r * 0.05, eyeY + r * 0.3), width: r * 0.12, height: r * 0.2),
          Paint()..color = const Color(0xFF7FD3FF),
        );
    }
  }

  Path _star(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(FacePainter old) => old.feeling != feeling;
}
