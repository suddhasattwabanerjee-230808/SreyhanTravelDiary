import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../diary_store.dart';
import '../places.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';
import '../widgets/stamp.dart';

/// My Passport: a cartoon map of Gujarat where every district a photo was
/// taken in gets stamped, then a page of stamps for the famous sights (the
/// ones still to find shown faint) and places around India. Tap any stamp to
/// hear its fun fact.
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  Set<String>? _stamps;
  Place? _picked;
  DiaryStore? _store;

  App get _app => App.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = _app.store;
    if (store != _store) {
      _store?.removeListener(_load);
      _store = store..addListener(_load);
      _load();
    }
  }

  Future<void> _load() async {
    final days = await _app.store.allDays();
    // Newest first, so the latest place is the one shown to start with.
    final visited = [
      for (final d in days)
        for (final m in d.moments.reversed)
          ...placesMentioned(m.text).map((p) => p.id),
    ];
    if (!mounted) return;
    setState(() {
      _stamps = passportStamps(visited);
      _picked ??= placeById(visited.firstOrNull);
    });
  }

  @override
  void dispose() {
    _store?.removeListener(_load);
    super.dispose();
  }

  @override
  void deactivate() {
    _app.speaker.stop();
    super.deactivate();
  }

  void _pick(Place p) {
    _app.sounds.play(Sfx.pop);
    setState(() => _picked = p);
    final has = _stamps!.contains(p.id);
    _app.speaker.say(has ? '${p.name}! ${p.fact}' : "${p.name}. Go there and take a photo to get this stamp!");
  }

  @override
  Widget build(BuildContext context) {
    final stamps = _stamps;
    final districtCount = stamps == null ? 0 : districts.where((d) => stamps.contains(d.id)).length;
    return Scaffold(
      body: BandhaniBackground(
        color: const Color(0xFFEFF8F4),
        dot: Gj.teal.withValues(alpha: 0.12),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    BlobButton(
                      icon: Icons.arrow_back_rounded,
                      color: Gj.peacock,
                      size: 56,
                      sound: Sfx.whoosh,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(child: Center(child: OutlinedTitle('My Passport', size: 30))),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              Expanded(
                child: stamps == null
                    ? const SizedBox()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          SheruSays(
                            stamps.isEmpty
                                ? 'Take photos on your trip, and each new place gets a stamp here!'
                                : 'You have $districtCount of ${districts.length} Gujarat stamps! Tap one to hear about it.',
                            size: 76,
                          ),
                          const SizedBox(height: 10),
                          _MapCard(stamps: stamps, picked: _picked, onPick: _pick),
                          if (_picked != null) ...[const SizedBox(height: 12), _FactCard(place: _picked!, inked: stamps.contains(_picked!.id))],
                          const SizedBox(height: 18),
                          const _Heading('Famous places'),
                          _StampGrid(places: landmarks, stamps: stamps, onPick: _pick),
                          if (cities.any((c) => stamps.contains(c.id))) ...[
                            const SizedBox(height: 18),
                            const _Heading('Around India'),
                            _StampGrid(places: [for (final c in cities) if (stamps.contains(c.id)) c], stamps: stamps, onPick: _pick),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Center(child: OutlinedTitle(text, size: 24, color: Gj.maroon, stroke: 6)),
  );
}

/// Where a lat/lng sits on the map, as a fraction of its width and height.
const _west = 68.2, _east = 74.7, _north = 24.85, _south = 20.0;
final _aspect = (_north - _south) / ((_east - _west) * cos(22.5 * pi / 180));

Offset _onMap(double lat, double lng, Size size) =>
    Offset((lng - _west) / (_east - _west) * size.width, (_north - lat) / (_north - _south) * size.height);

class _MapCard extends StatelessWidget {
  const _MapCard({required this.stamps, required this.picked, required this.onPick});
  final Set<String> stamps;
  final Place? picked;
  final void Function(Place) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = Size(box.maxWidth, box.maxWidth * _aspect);
            final seen = [for (final p in [...districts, ...landmarks]) if (stamps.contains(p.id)) p];
            return SizedBox.fromSize(
              size: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _GujaratPainter()))),
                  // Districts not visited yet: small dots to aim for.
                  for (final d in districts)
                    if (!stamps.contains(d.id)) _pin(d, size, _Dot(selected: picked == d)),
                  for (final p in seen) _pin(p, size, _Marker(place: p, selected: picked == p)),
                  const Positioned(left: 12, bottom: 8, child: _SeaLabel('Arabian Sea')),
                  const Positioned(left: 14, top: 10, child: _SeaLabel('Kutch', color: Gj.maroon)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pin(Place p, Size size, Widget child) {
    final at = _onMap(p.lat, p.lng, size);
    const box = 44.0;
    return Positioned(
      left: at.dx - box / 2,
      top: at.dy - box / 2,
      width: box,
      height: box,
      child: Semantics(
        button: true,
        label: p.name,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onPick(p), child: Center(child: child)),
      ),
    );
  }
}

class _SeaLabel extends StatelessWidget {
  const _SeaLabel(this.text, {this.color = Gj.peacock});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.7), fontStyle: FontStyle.italic),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: selected ? 16 : 11,
    height: selected ? 16 : 11,
    decoration: BoxDecoration(
      color: const Color(0xFFD8CCB0),
      shape: BoxShape.circle,
      border: Border.all(color: selected ? Gj.ink : Colors.white, width: 2),
    ),
  );
}

/// A stamped place on the map: a little round seal, or a star for a sight.
class _Marker extends StatelessWidget {
  const _Marker({required this.place, required this.selected});
  final Place place;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final sight = place.kind == PlaceKind.landmark;
    final d = sight ? 22.0 : 28.0;
    return AnimatedScale(
      scale: selected ? 1.35 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: place.color,
          shape: sight ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: sight ? BorderRadius.circular(7) : null,
          border: Border.all(color: selected ? Gj.ink : Colors.white, width: 2.5),
          boxShadow: [BoxShadow(color: Gj.edge(place.color), offset: const Offset(0, 2))],
        ),
        child: Icon(sight ? Icons.star_rounded : place.icon, color: Colors.white, size: d * 0.6),
      ),
    );
  }
}

/// Sea, the land with a white coastline, and the white salt deserts.
class _GujaratPainter extends CustomPainter {
  const _GujaratPainter();

  Path _path(List<(double, double)> pts, Size size) {
    final path = Path();
    for (final (i, (lat, lng)) in pts.indexed) {
      final o = _onMap(lat, lng, size);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = const LinearGradient(colors: [Color(0xFF9FDDF0), Color(0xFF6CC3E3)], begin: Alignment.topRight, end: Alignment.bottomLeft).createShader(rect),
    );
    // Little waves.
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rnd = Random(4);
    for (var i = 0; i < 26; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawArc(Rect.fromCenter(center: o, width: 14, height: 8), pi * 1.1, pi * 0.8, false, wave);
      canvas.drawArc(Rect.fromCenter(center: o + const Offset(12, 0), width: 14, height: 8), pi * 1.1, pi * 0.8, false, wave);
    }
    final land = _path(gujaratOutline, size);
    canvas.drawShadow(land, const Color(0xFF2A6F86), 6, false);
    canvas.drawPath(
      land,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      land,
      Paint()..shader = const RadialGradient(center: Alignment(0.3, 0.1), radius: 0.9, colors: [Color(0xFFFFE9B8), Color(0xFFF4CF88)]).createShader(rect),
    );
    // The white salt Rann, sparkling.
    final salt = Paint()..color = const Color(0xFFFDFCF7);
    final sparkle = Paint()..color = const Color(0xFFBFE6F5);
    for (final rann in [greatRann, littleRann]) {
      final p = _path(rann, size);
      canvas.drawPath(p, salt);
      final b = p.getBounds();
      for (var i = 0; i < 14; i++) {
        final o = Offset(b.left + rnd.nextDouble() * b.width, b.top + rnd.nextDouble() * b.height);
        if (p.contains(o)) canvas.drawCircle(o, 1.6, sparkle);
      }
    }
  }

  @override
  bool shouldRepaint(_GujaratPainter old) => false;
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.place, required this.inked});
  final Place place;
  final bool inked;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    return GestureDetector(
      onTap: () => app.speaker.say(inked ? '${place.name}! ${place.fact}' : place.name),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: inked ? place.color : const Color(0xFFC9C3DA), width: 3.5),
        ),
        child: Row(
          children: [
            PlaceStamp(place, size: 86, inked: inked, tilt: -0.08),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Gj.edge(inked ? place.color : Gj.inkSoft), height: 1.1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inked ? place.fact : 'Not stamped yet. Go there and take a photo!',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Gj.ink, height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StampGrid extends StatelessWidget {
  const _StampGrid({required this.places, required this.stamps, required this.onPick});
  final List<Place> places;
  final Set<String> stamps;
  final void Function(Place) onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (i, p) in places.indexed)
          Semantics(
            button: true,
            label: p.name,
            child: GestureDetector(
              onTap: () => onPick(p),
              child: PlaceStamp(p, size: 96, inked: stamps.contains(p.id), tilt: (i % 3 - 1) * 0.07),
            ),
          ),
      ],
    );
  }
}

