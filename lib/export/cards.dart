import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';

/// Turns a moment's photo path into an image (the diary folder's file).
typedef PhotoOf = ImageProvider Function(Moment m);

/// A picture postcard of one day: a collage of its photos, Sheru as the
/// stamp, and the child's own words. Drawn at 600 x 400 and saved at 3x.
class Postcard extends StatelessWidget {
  const Postcard({super.key, required this.day, required this.photoOf, required this.childName});
  final DiaryDay day;
  final PhotoOf photoOf;
  final String childName;

  static const size = Size(600, 400);

  @override
  Widget build(BuildContext context) {
    final moments = day.moments.take(3).toList();
    final words = day.moments.map((m) => m.text).join(' ');
    return SizedBox.fromSize(
      size: size,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Gj.kumkum, width: 10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BandhaniBackground(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 300, child: _Collage(moments: moments, photoOf: photoOf)),
                  const SizedBox(width: 10),
                  Container(width: 2, color: Gj.inkSoft.withValues(alpha: 0.25)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Align(alignment: Alignment.topRight, child: _Stamp()),
                        const SizedBox(height: 4),
                        const RainbowTitle('Greetings!', size: 30),
                        OutlinedTitle(prettyDate(day.day), size: 15, color: Gj.inkSoft, stroke: 4),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            words,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25, color: Gj.ink),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            'Love, $childName',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Gj.kumkum),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Collage extends StatelessWidget {
  const _Collage({required this.moments, required this.photoOf});
  final List<Moment> moments;
  final PhotoOf photoOf;

  @override
  Widget build(BuildContext context) {
    // Up to three snaps, overlapping like they were stuck on by hand.
    const spots = [
      (Offset(4, 6), 0.06, 190.0),
      (Offset(104, 120), -0.05, 190.0),
      (Offset(10, 190), 0.03, 150.0),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = moments.length - 1; i >= 0; i--)
          Positioned(
            left: spots[i].$1.dx,
            top: spots[i].$1.dy,
            width: moments.length == 1 ? 280 : spots[i].$3,
            child: Polaroid(
              image: photoOf(moments[i]),
              tilt: spots[i].$2,
              tapeColor: Gj.festive[i * 2],
            ),
          ),
      ],
    );
  }
}

/// Sheru as a postage stamp, with a postmark.
class _Stamp extends StatelessWidget {
  const _Stamp();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 92,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            child: Container(
              width: 76,
              height: 92,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Gj.saffron, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: Column(
                children: [
                  const Expanded(child: FittedBox(child: Sheru(size: 80))),
                  Text('INDIA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Gj.edge(Gj.saffron))),
                ],
              ),
            ),
          ),
          Positioned(left: 0, top: 22, child: CustomPaint(size: const Size(70, 48), painter: _Postmark())),
        ],
      ),
    );
  }
}

class _Postmark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Gj.inkSoft.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(size.height / 2, size.height / 2), size.height / 2 - 2, p);
    for (var i = 0; i < 4; i++) {
      final y = 8.0 + i * 10;
      final path = Path()..moveTo(size.height * 0.6, y);
      for (var x = size.height * 0.6; x < size.width + 20; x += 10) {
        path.relativeQuadraticBezierTo(5, i.isEven ? -4 : 4, 10, 0);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_Postmark old) => false;
}

/// A comic strip of one day: each photo a panel with the child's words in a
/// speech bubble, two panels to a row. Up to six panels; an odd one out is
/// joined by Sheru's "The End!".
class ComicStrip extends StatelessWidget {
  const ComicStrip({super.key, required this.day, required this.photoOf, required this.childName});
  final DiaryDay day;
  final PhotoOf photoOf;
  final String childName;

  static const width = 600.0;
  static const _panel = 280.0;

  /// The strip's height for [panels] moments.
  static double heightFor(int panels) => 96 + ((min(panels, 6) + 1) ~/ 2) * (_panel + 14) + 34;

  @override
  Widget build(BuildContext context) {
    final moments = day.moments.take(6).toList();
    final cells = <Widget>[
      for (final (i, m) in moments.indexed) _Panel(number: i + 1, image: photoOf(m), words: m.text),
      if (moments.length.isOdd) const _TheEnd(),
    ];
    return Container(
      width: width,
      height: heightFor(moments.length),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Container(
            height: 72,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Gj.marigold,
              border: Border.all(color: Colors.black, width: 4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedTitle("$childName's Adventure!", size: 30, color: Gj.kumkum, stroke: 6),
                const SizedBox(width: 12),
                OutlinedTitle(shortDate(day.day), size: 18, color: Gj.ink, stroke: 5),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [for (final c in cells) SizedBox(width: _panel, height: _panel, child: c)],
            ),
          ),
          const Text(
            "Made with Sreyhan's Travel Diary",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Gj.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.number, required this.image, required this.words});
  final int number;
  final ImageProvider image;
  final String words;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 4)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: image, fit: BoxFit.cover, gaplessPlayback: true),
          Positioned(
            left: 6,
            top: 6,
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.black,
              child: Text('$number', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: CustomPaint(
              painter: _ComicBubble(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Text(
                  words,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.15, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicBubble extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    final tail = Path()
      ..moveTo(24, 1)
      ..lineTo(18, -14)
      ..lineTo(42, 1)
      ..close();
    final shape = Path.combine(PathOperation.union, Path()..addRRect(body), tail);
    canvas.drawPath(shape, Paint()..color = Colors.white);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_ComicBubble old) => false;
}

class _TheEnd extends StatelessWidget {
  const _TheEnd();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Gj.sand, border: Border.all(color: Colors.black, width: 4)),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Sheru(size: 150, happy: true),
          SizedBox(height: 8),
          OutlinedTitle('The End!', size: 34, color: Gj.kumkum),
        ],
      ),
    );
  }
}
