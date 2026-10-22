import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../sound_board.dart';
import '../theme.dart';
import 'photo.dart';

/// A chunky 3D button trimmed with Kutch mirror-work: little round mirrors
/// around the edge that glint. It sinks when pressed and goes "pop".
class KutchButton extends StatefulWidget {
  const KutchButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = Gj.saffron,
    this.height = 76,
    this.fontSize = 26,
    this.sound = Sfx.pop,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final double height;
  final double fontSize;
  final Sfx sound;

  @override
  State<KutchButton> createState() => _KutchButtonState();
}

class _KutchButtonState extends State<KutchButton> with SingleTickerProviderStateMixin {
  bool _down = false;
  late final _glint = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _glint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = enabled ? widget.color : const Color(0xFFBDB6CF);
    const depth = 7.0;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.lightImpact();
                App.of(context).sounds.play(widget.sound);
                widget.onTap!();
              }
            : null,
        child: SizedBox(
          height: widget.height + depth,
          child: Stack(
            children: [
              Positioned.fill(
                top: depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Gj.edge(color),
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: _down ? depth - 1 : 0,
                height: widget.height,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _glint,
                    builder: (context, child) => CustomPaint(
                      painter: _MirrorWorkPainter(color: color, glint: _glint.value),
                      child: child,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: widget.fontSize * 1.3),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: widget.fontSize,
                                fontWeight: FontWeight.w800,
                                shadows: const [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 2)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Where the mirrors sit along a button's stitched edge. Worked out once per
/// button size, not on every frame of the glint.
final _mirrorCache = <RRect, List<Offset>>{};

List<Offset> _mirrorsFor(RRect edge) {
  if (_mirrorCache.length > 32) _mirrorCache.clear();
  return _mirrorCache.putIfAbsent(edge, () {
    // Path metrics can be walked only once.
    final it = (Path()..addRRect(edge)).computeMetrics().iterator;
    if (!it.moveNext()) return const [];
    final metric = it.current;
    final count = max(8, (metric.length / 34).floor());
    return [for (var i = 0; i < count; i++) ?metric.getTangentForOffset(metric.length * i / count)?.position];
  });
}

class _MirrorWorkPainter extends CustomPainter {
  _MirrorWorkPainter({required this.color, required this.glint});
  final Color color;
  final double glint;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final body = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ).createShader(Offset.zero & size),
    );
    // Glossy top highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(r * 0.5, 5, size.width - r, size.height * 0.32), Radius.circular(r)),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    // Stitched border.
    final inset = body.deflate(6);
    canvas.drawRRect(
      inset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    // Mirrors along the stitched line; one glint travels round.
    final mirrors = _mirrorsFor(inset);
    final count = mirrors.length;
    for (var i = 0; i < count; i++) {
      final pos = mirrors[i];
      final shine = (1 - ((i / count - glint).abs() * 6)).clamp(0.0, 1.0);
      canvas.drawCircle(pos, 4.2, Paint()..color = Color.lerp(const Color(0xFFDDE6F0), Colors.white, shine)!);
      canvas.drawCircle(
        pos,
        4.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Gj.edge(color),
      );
      if (shine > 0.5) {
        canvas.drawCircle(pos, 7 * shine, Paint()..color = Colors.white.withValues(alpha: 0.35 * shine));
      }
    }
  }

  @override
  bool shouldRepaint(_MirrorWorkPainter old) => old.glint != glint || old.color != color;
}

/// A round chunky icon button, for Back, Again, Done and the like.
class BlobButton extends StatefulWidget {
  const BlobButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = Gj.peacock,
    this.size = 64,
    this.label,
    this.sound = Sfx.pop,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final String? label;
  final Sfx sound;

  @override
  State<BlobButton> createState() => _BlobButtonState();
}

class _BlobButtonState extends State<BlobButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? widget.color : const Color(0xFFC9C3DA);
    final circle = AnimatedScale(
      scale: _down ? 0.88 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [Color.lerp(c, Colors.white, 0.3)!, c]),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [BoxShadow(color: Gj.edge(c), offset: const Offset(0, 5))],
        ),
        child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.5),
      ),
    );
    // The label is part of the button: children tap the word as often as the circle.
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.selectionClick();
                App.of(context).sounds.play(widget.sound);
                widget.onTap!();
              }
            : null,
        child: widget.label == null
            ? circle
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  circle,
                  const SizedBox(height: 4),
                  Text(
                    widget.label!,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: enabled ? Gj.ink : Gj.inkSoft),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A photo in a white instant-camera frame, a little tilted, with tape.
class Polaroid extends StatelessWidget {
  const Polaroid({super.key, required this.image, this.tilt = -0.04, this.caption, this.tapeColor = Gj.marigold});
  final ImageProvider image;
  final double tilt;
  final Widget? caption;
  final Color tapeColor;

  static ImageProvider file(String path) => FileImage(File(path));

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: AspectRatio(aspectRatio: 4 / 3, child: SizedPhoto(image)),
                ),
                if (caption != null) ...[const SizedBox(height: 10), caption!],
              ],
            ),
          ),
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -tilt * 2 + 0.05,
                child: Container(
                  width: 86,
                  height: 26,
                  decoration: BoxDecoration(
                    color: tapeColor.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One spoken word as a bubble the child can tap to fix.
class WordBubble extends StatelessWidget {
  const WordBubble({
    super.key,
    required this.word,
    required this.color,
    this.live = false,
    this.selected = false,
    this.onTap,
  });
  final String word;
  final Color color;

  /// Still being heard: lighter and dashed.
  final bool live;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: live ? Colors.white : (selected ? Gj.edge(color) : color),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: live ? color.withValues(alpha: 0.6) : Colors.white, width: 3),
          boxShadow: live
              ? null
              : [BoxShadow(color: Gj.edge(color).withValues(alpha: 0.6), offset: const Offset(0, 3))],
        ),
        child: Text(
          word,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.15, color: live ? color : Colors.white),
        ),
      ),
    );
  }
}

/// Bandhani: tie-dye dot clusters scattered over a colour.
class BandhaniBackground extends StatelessWidget {
  const BandhaniBackground({super.key, this.color = Gj.sand, this.dot = const Color(0x22E53950), required this.child});
  final Color color;
  final Color dot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Thousands of dots: drawn once into their own layer and reused, instead
    // of again every time something on the page animates.
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(isComplex: true, painter: _BandhaniPainter(color, dot))),
        ),
        child,
      ],
    );
  }
}

class _BandhaniPainter extends CustomPainter {
  _BandhaniPainter(this.color, this.dot);
  final Color color, dot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final p = Paint()..color = dot;
    const gap = 46.0;
    for (var row = 0; row * gap < size.height + gap; row++) {
      for (var col = 0; col * gap < size.width + gap; col++) {
        final c = Offset(col * gap + (row.isOdd ? gap / 2 : 0), row * gap);
        canvas.drawCircle(c, 2.6, p);
        for (var k = 0; k < 6; k++) {
          final a = k * pi / 3;
          canvas.drawCircle(c + Offset(cos(a), sin(a)) * 7, 1.8, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BandhaniPainter old) => old.color != color || old.dot != dot;
}

/// A burst of confetti and tiny kites. Shown on top of everything for a
/// moment, then removes itself.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.onDone});
  final VoidCallback? onDone;

  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(child: ConfettiBurst(onDone: () => entry.remove())),
    );
    overlay.insert(entry);
  }

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward().whenComplete(() => widget.onDone?.call());
  final _bits = List.generate(70, (i) => _Bit(Random(i * 31 + 7)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_bits, _c.value)),
    );
  }
}

class _Bit {
  _Bit(Random r)
    : x = r.nextDouble(),
      vx = (r.nextDouble() - 0.5) * 0.5,
      vy = 0.9 + r.nextDouble() * 0.9,
      spin = (r.nextDouble() - 0.5) * 18,
      color = Gj.festive[r.nextInt(Gj.festive.length)],
      kite = r.nextDouble() < 0.2,
      size = 7 + r.nextDouble() * 8;
  final double x, vx, vy, spin, size;
  final Color color;
  final bool kite;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);
  final List<_Bit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      // Thrown up from the bottom, then falling with gravity.
      final y = size.height * (1.05 - b.vy * t * 1.6 + 1.5 * t * t);
      final x = size.width * (b.x + b.vx * t);
      final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
      final paint = Paint()..color = b.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * t);
      if (b.kite) {
        final k = b.size * 1.3;
        canvas.drawPath(
          Path()
            ..moveTo(0, -k)
            ..lineTo(k * 0.75, 0)
            ..lineTo(0, k)
            ..lineTo(-k * 0.75, 0)
            ..close(),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
