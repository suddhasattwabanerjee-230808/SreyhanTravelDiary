import 'dart:math';

import 'package:flutter/material.dart';

import '../places.dart';
import '../theme.dart';

/// A passport stamp: a round inked seal with a scalloped edge, the place's
/// picture in the middle and its name around the bottom. Grey and faint
/// until [inked].
class PlaceStamp extends StatelessWidget {
  const PlaceStamp(this.place, {super.key, this.size = 84, this.inked = true, this.tilt = 0});
  final Place place;
  final double size;
  final bool inked;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final color = inked ? place.color : const Color(0xFFC9C3DA);
    return Transform.rotate(
      angle: tilt,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _StampPainter(color, inked),
          child: Padding(
            padding: EdgeInsets.all(size * 0.16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(place.icon, color: inked ? Colors.white : Colors.white70, size: size * 0.36),
                Text(
                  place.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: size * (place.name.length > 11 ? 0.1 : 0.13),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter(this.color, this.inked);
  final Color color;
  final bool inked;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Scalloped edge, like a perforated stamp.
    final edge = Path();
    const bumps = 22;
    for (var i = 0; i <= bumps * 2; i++) {
      final a = i * pi / bumps;
      final rr = i.isEven ? r : r * 0.92;
      final p = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? edge.moveTo(p.dx, p.dy) : edge.lineTo(p.dx, p.dy);
    }
    edge.close();
    if (inked) canvas.drawShadow(edge, Gj.edge(color), 3, false);
    canvas.drawPath(edge, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * 0.84, Paint()..color = color);
    canvas.drawCircle(
      c,
      r * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_StampPainter old) => old.color != color || old.inked != inked;
}

/// A small "pin + place name" label, for a photo or a day.
class PlacePill extends StatelessWidget {
  const PlacePill(this.place, {super.key, this.size = 16, this.onTap});
  final Place place;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(size * 0.5, size * 0.25, size * 0.8, size * 0.25),
        decoration: BoxDecoration(
          color: place.color,
          borderRadius: BorderRadius.circular(size * 2),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: Gj.edge(place.color), offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_rounded, color: Colors.white, size: size * 1.3),
            SizedBox(width: size * 0.2),
            Flexible(
              child: Text(
                place.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: size * 0.3),
              Icon(Icons.volume_up_rounded, color: Colors.white, size: size * 1.1),
            ],
          ],
        ),
      ),
    );
  }
}
