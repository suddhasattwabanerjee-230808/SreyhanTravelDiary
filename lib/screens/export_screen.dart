import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_channel.dart';
import '../app_scope.dart';
import '../export/cards.dart';
import '../export/share.dart';
import '../export/storybook.dart';
import '../models.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';
import 'home_screen.dart' show childName;

enum _Picture { postcard, comic }

/// "Share my day": a storybook (this day or the whole trip), a postcard or a
/// comic strip, each handed to Android's share sheet for WhatsApp, Drive,
/// printing and the rest.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.date});
  final String date;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String? _busy;
  String? _say;

  App get _app => App.of(context);

  Future<void> _storybook({required bool wholeTrip}) async {
    setState(() {
      _busy = 'Making your storybook...';
      _say = null;
    });
    try {
      final store = _app.store;
      final days = wholeTrip ? (await store.allDays()).reversed.toList() : [await store.day(widget.date)];
      final pdf = await buildStorybook(store, days, childName: childName);
      _app.sounds.play(Sfx.sparkle);
      await Sharer.shareBytes(
        pdf,
        '${exportName(wholeTrip ? 'trip-storybook' : 'storybook', widget.date)}.pdf',
        mime: 'application/pdf',
        title: "$childName's storybook",
      );
      _say = 'Here it is! Send it, or print it.';
    } catch (e, st) {
      reportError('Storybook: $e', st);
      _say = "Oops, that didn't work. Try again!";
    }
    if (mounted) setState(() => _busy = null);
  }

  void _picture(_Picture kind) {
    _app.sounds.play(Sfx.whoosh);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _PictureScreen(date: widget.date, kind: kind)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BandhaniBackground(
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
                    const Expanded(child: Center(child: OutlinedTitle('Share my day', size: 30))),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SheruSays(_busy ?? _say ?? 'What shall we make from your day?', size: 80, happy: _say != null),
              ),
              Expanded(
                child: IgnorePointer(
                  ignoring: _busy != null,
                  child: AnimatedOpacity(
                    opacity: _busy != null ? 0.4 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      children: [
                        _Choice(
                          icon: Icons.photo_album_rounded,
                          color: Gj.saffron,
                          title: 'Picture postcard',
                          blurb: 'Your photos and words on one card',
                          onTap: () => _picture(_Picture.postcard),
                        ),
                        _Choice(
                          icon: Icons.chat_bubble_rounded,
                          color: Gj.peacock,
                          title: 'Comic strip',
                          blurb: 'Your photos as comic panels',
                          onTap: () => _picture(_Picture.comic),
                        ),
                        _Choice(
                          icon: Icons.menu_book_rounded,
                          color: Gj.leaf,
                          title: 'Storybook of this day',
                          blurb: 'A book to print (PDF)',
                          onTap: () => _storybook(wholeTrip: false),
                        ),
                        _Choice(
                          icon: Icons.auto_stories_rounded,
                          color: Gj.lilac,
                          title: 'Storybook of my whole trip',
                          blurb: 'Every day, one big book (PDF)',
                          onTap: () => _storybook(wholeTrip: true),
                        ),
                      ],
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

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.color, required this.title, required this.blurb, required this.onTap});
  final IconData icon;
  final Color color;
  final String title, blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () {
          App.of(context).sounds.play(Sfx.pop);
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 3.5),
            boxShadow: [BoxShadow(color: Gj.edge(color).withValues(alpha: 0.5), offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Gj.edge(color), height: 1.1)),
                    Text(blurb, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Gj.inkSoft)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}

/// The postcard or comic, shown to fit the screen, and saved as a sharp
/// picture when shared.
class _PictureScreen extends StatefulWidget {
  const _PictureScreen({required this.date, required this.kind});
  final String date;
  final _Picture kind;

  @override
  State<_PictureScreen> createState() => _PictureScreenState();
}

class _PictureScreenState extends State<_PictureScreen> {
  final _frame = GlobalKey();
  DiaryDay? _day;
  bool _ready = false;
  bool _sharing = false;

  App get _app => App.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_day == null) _load();
  }

  Future<void> _load() async {
    final day = await _app.store.day(widget.date);
    if (!mounted) return;
    setState(() => _day = day);
    // Every photo fully loaded before the picture can be saved.
    await Future.wait([for (final m in day.moments.take(6)) precacheImage(_photoOf(m), context)]);
    if (mounted) setState(() => _ready = true);
  }

  ImageProvider _photoOf(Moment m) => FileImage(File(_app.store.file(m.photo).path));

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      _app.sounds.play(Sfx.sparkle);
      final what = widget.kind == _Picture.postcard ? 'postcard' : 'comic';
      await Sharer.shareBytes(
        png!.buffer.asUint8List(),
        '${exportName(what, widget.date)}.png',
        mime: 'image/png',
        title: "$childName's $what",
      );
    } catch (e, st) {
      reportError('Sharing a picture: $e', st);
    }
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final postcard = widget.kind == _Picture.postcard;
    final Widget? card = day == null
        ? null
        : postcard
        ? Postcard(day: day, photoOf: _photoOf, childName: childName)
        : ComicStrip(day: day, photoOf: _photoOf, childName: childName);
    return Scaffold(
      body: BandhaniBackground(
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
                    Expanded(child: Center(child: OutlinedTitle(postcard ? 'Postcard' : 'Comic strip', size: 30))),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              Expanded(
                child: card == null
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.all(14),
                        child: Center(
                          child: FittedBox(
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                boxShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 18, offset: Offset(0, 8))],
                              ),
                              child: RepaintBoundary(key: _frame, child: card),
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: KutchButton(
                  label: _sharing ? 'Getting it ready...' : (_ready ? 'Share it' : 'Loading photos...'),
                  icon: Icons.share_rounded,
                  color: Gj.leaf,
                  onTap: _ready && !_sharing ? _share : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
