import 'dart:math';

import 'package:flutter/material.dart';

/// Sheru, the Gir lion cub: the app's guide and its talk button.
/// He bobs, blinks, and opens his mouth with the child's voice.
class Sheru extends StatefulWidget {
  const Sheru({super.key, this.size = 160, this.listening = false, this.level = 0, this.happy = false});

  final double size;

  /// Ears up and mouth moving with [level] (0 to 1).
  final bool listening;
  final double level;

  /// A big open grin, for celebrations.
  final bool happy;

  @override
  State<Sheru> createState() => _SheruState();
}

class _SheruState extends State<Sheru> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _clock.value;
          // Blink twice per loop, briefly.
          final blink = _blinkAt(t, 0.32) + _blinkAt(t, 0.82);
          final mouth = widget.happy ? 0.75 : (widget.listening ? 0.2 + 0.8 * widget.level : 0.0);
          return SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(
              painter: SheruPainter(
                bob: sin(t * 2 * pi * (widget.listening ? 2 : 1)),
                blink: blink.clamp(0.0, 1.0),
                mouth: mouth,
                earsUp: widget.listening,
              ),
            ),
          );
        },
      ),
    );
  }

  double _blinkAt(double t, double at) {
    final d = (t - at).abs();
    return d < 0.025 ? 1 - d / 0.025 : 0;
  }
}

class SheruPainter extends CustomPainter {
  SheruPainter({this.bob = 0, this.blink = 0, this.mouth = 0, this.earsUp = false});

  final double bob, blink, mouth;
  final bool earsUp;

  static const _outline = Color(0xFF5A3214);
  static const _maneOuter = Color(0xFFD9741F);
  static const _maneInner = Color(0xFFF0973A);
  static const _fur = Color(0xFFFFCB64);
  static const _muzzle = Color(0xFFFFF0CC);
  static const _ear = Color(0xFFF7B84B);
  static const _earIn = Color(0xFFF59A8C);
  static const _blush = Color(0x66FF6B81);

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 200 x 200 grid centred on the face.
    final s = size.width / 200;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + bob * 3 * s);
    canvas.scale(s);

    final line = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint fill(Color c) => Paint()..color = c;

    // Mane: a scalloped flower of tufts.
    final mane = Path();
    const tufts = 13;
    for (var i = 0; i < tufts; i++) {
      final a = i / tufts * 2 * pi + bob * 0.03;
      mane.addOval(Rect.fromCircle(center: Offset(cos(a) * 70, sin(a) * 70 + 4), radius: 27));
    }
    mane.addOval(Rect.fromCircle(center: const Offset(0, 4), radius: 74));
    canvas.drawPath(mane, line..strokeWidth = 9);
    canvas.drawPath(mane, fill(_maneOuter));
    canvas.drawCircle(const Offset(0, 6), 66, fill(_maneInner));
    line.strokeWidth = 4.5;

    // Ears, perking up while listening.
    final earLift = earsUp ? -8.0 : 0.0;
    for (final side in [-1.0, 1.0]) {
      final c = Offset(side * 44, -44 + earLift);
      canvas.drawCircle(c, 19, fill(_ear));
      canvas.drawCircle(c, 19, line);
      canvas.drawCircle(c + Offset(side * 1, 2), 10, fill(_earIn));
    }

    // Face.
    final face = Rect.fromCenter(center: const Offset(0, 8), width: 116, height: 108);
    canvas.drawOval(face, fill(_fur));
    canvas.drawOval(face, line);

    // Little brow tuft on top.
    final tuft = Path()
      ..moveTo(-10, -44)
      ..quadraticBezierTo(-4, -58, 2, -46)
      ..quadraticBezierTo(8, -58, 12, -44);
    canvas.drawPath(tuft, line..strokeWidth = 3.5);
    line.strokeWidth = 4.5;

    // Cheeks.
    canvas.drawCircle(const Offset(-36, 26), 11, fill(_blush));
    canvas.drawCircle(const Offset(36, 26), 11, fill(_blush));

    // Eyes: big, shiny, and they blink.
    for (final side in [-1.0, 1.0]) {
      final c = Offset(side * 23, -2);
      final h = 26 * (1 - blink * 0.92);
      if (blink > 0.7) {
        canvas.drawArc(Rect.fromCenter(center: c, width: 20, height: 10), 0.2, pi - 0.4, false, line);
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: 21, height: h), fill(const Color(0xFF2A1A10)));
        canvas.drawCircle(c + const Offset(4, -6), 4.5, fill(Colors.white));
        canvas.drawCircle(c + const Offset(-4, 5), 2, fill(Colors.white70));
      }
    }

    // Muzzle.
    canvas.drawOval(Rect.fromCenter(center: const Offset(-13, 30), width: 34, height: 26), fill(_muzzle));
    canvas.drawOval(Rect.fromCenter(center: const Offset(13, 30), width: 34, height: 26), fill(_muzzle));

    // Mouth: a smile, or open when talking.
    if (mouth > 0.05) {
      final open = Rect.fromCenter(center: Offset(0, 40 + mouth * 4), width: 26 + mouth * 6, height: 8 + mouth * 20);
      canvas.drawOval(open, fill(const Color(0xFF8A1C2B)));
      canvas.save();
      canvas.clipPath(Path()..addOval(open));
      canvas.drawCircle(Offset(0, open.bottom + 2), open.width * 0.38, fill(const Color(0xFFFF7C8E)));
      canvas.restore();
      canvas.drawOval(open, line..strokeWidth = 3.5);
    } else {
      final smile = Path()
        ..moveTo(-14, 36)
        ..quadraticBezierTo(-7, 45, 0, 36)
        ..quadraticBezierTo(7, 45, 14, 36);
      canvas.drawPath(smile, line..strokeWidth = 3.5);
    }
    line.strokeWidth = 4.5;

    // Nose on top of everything.
    final nose = Path()
      ..moveTo(-10, 18)
      ..quadraticBezierTo(0, 14, 10, 18)
      ..quadraticBezierTo(8, 28, 0, 30)
      ..quadraticBezierTo(-8, 28, -10, 18)
      ..close();
    canvas.drawPath(nose, fill(const Color(0xFF6B3A1E)));
    canvas.drawCircle(const Offset(-3, 19), 2.2, fill(Colors.white54));

    // Whisker dots.
    for (final p in const [Offset(-20, 30), Offset(-25, 36), Offset(-17, 38), Offset(20, 30), Offset(25, 36), Offset(17, 38)]) {
      canvas.drawCircle(p, 1.6, fill(_outline));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(SheruPainter old) =>
      old.bob != bob || old.blink != blink || old.mouth != mouth || old.earsUp != earsUp;
}

/// Sheru with a speech bubble beside him.
class SheruSays extends StatelessWidget {
  const SheruSays(this.message, {super.key, this.size = 92, this.listening = false, this.level = 0, this.happy = false});
  final String message;
  final double size;
  final bool listening;
  final double level;
  final bool happy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Sheru(size: size, listening: listening, level: level, happy: happy),
        const SizedBox(width: 4),
        Flexible(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
              alignment: Alignment.centerLeft,
              child: child,
            ),
            child: SpeechBubble(message, key: ValueKey(message)),
          ),
        ),
      ],
    );
  }
}

class SpeechBubble extends StatelessWidget {
  const SpeechBubble(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 12, 16, 12),
        child: Text(
          text,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.15, color: Color(0xFF2B2350)),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(10, 0, size.width - 10, size.height), const Radius.circular(22));
    final tail = Path()
      ..moveTo(12, size.height * 0.42)
      ..lineTo(0, size.height * 0.56)
      ..lineTo(14, size.height * 0.64)
      ..close();
    final shape = Path.combine(PathOperation.union, Path()..addRRect(body), tail);
    canvas.drawShadow(shape, Colors.black26, 4, false);
    canvas.drawPath(shape, Paint()..color = Colors.white);
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xFF2B2350)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => false;
}
