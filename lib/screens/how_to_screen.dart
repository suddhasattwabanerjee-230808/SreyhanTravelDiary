import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../feelings.dart';
import '../places.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/mic_button.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';
import '../widgets/sky.dart';
import '../widgets/stamp.dart';

/// Remembers that the guide was shown, so it opens by itself only once.
const seenGuideKey = 'seenGuide';

class _Page {
  const _Page(this.title, this.say, this.color, this.picture);
  final String title;

  /// Short and simple: Sheru reads it aloud too.
  final String say;
  final Color color;
  final Widget Function() picture;
}

final _pages = [
  _Page(
    'Take a photo',
    'Tap Add a picture. Take a photo, or pick one you already have.',
    Gj.saffron,
    () => const _Pretend(child: KutchButton(label: 'Add a picture', icon: Icons.add_a_photo_rounded, onTap: _nothing)),
  ),
  _Page(
    'Talk to me',
    'Tap the mic and tell me about your photo. Tap it again when you finish.',
    Gj.kumkum,
    () => const _Pretend(child: MicButton(listening: false, level: 0, onTap: _nothing)),
  ),
  _Page(
    'Fix a word',
    'Did I write a word wrong? Tap it, and type it the right way.',
    Gj.peacock,
    () => const _FixAWord(),
  ),
  _Page(
    'Bengali or Hindi',
    "Don't know a word in English? Tap Bengali or Hindi and say it. I will tell you the English word!",
    Gj.teal,
    () => const _Bridge(),
  ),
  _Page(
    'Say more',
    'Tap a face to show how you felt, and tell me why. Tap See, Hear, Smell, Touch or Taste for more ideas!',
    Gj.lilac,
    () => const _SayMore(),
  ),
  _Page(
    'Save it',
    'Tap Done. Your photo goes into your diary. Every day is a kite in the sky!',
    Gj.leaf,
    () => const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pretend(child: BlobButton(icon: Icons.check_rounded, color: Gj.leaf, size: 84, label: 'Done', onTap: _nothing)),
        SizedBox(width: 28),
        FlyingKite(width: 110, color: Gj.kumkum, accent: Gj.marigold, child: Icon(Icons.favorite_rounded, color: Gj.kumkum)),
      ],
    ),
  ),
  _Page(
    'Read your day',
    'Tap a kite to see that day. Tap the speaker, and I will read it to you. Tap the moon, and I will read you the whole day!',
    Gj.lilac,
    () => const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FlyingKite(width: 90, color: Gj.peacock, accent: Gj.leaf, child: Text('3', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Gj.peacock))),
        SizedBox(width: 16),
        _Pretend(child: BlobButton(icon: Icons.volume_up_rounded, color: Gj.teal, size: 70, onTap: _nothing)),
        SizedBox(width: 12),
        _Pretend(child: BlobButton(icon: Icons.bedtime_rounded, color: Gj.lilac, size: 70, onTap: _nothing)),
      ],
    ),
  ),
  _Page(
    'Share my day',
    'In a day, tap the green share button. Make a postcard, a comic or a storybook, and send it to your family!',
    Gj.leaf,
    () => const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pretend(child: BlobButton(icon: Icons.share_rounded, color: Gj.leaf, size: 84, onTap: _nothing)),
        SizedBox(width: 18),
        Icon(Icons.arrow_forward_rounded, color: Gj.leaf, size: 36),
        SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_album_rounded, color: Gj.saffron, size: 46),
            Icon(Icons.chat_bubble_rounded, color: Gj.peacock, size: 46),
            Icon(Icons.menu_book_rounded, color: Gj.leaf, size: 46),
          ],
        ),
      ],
    ),
  ),
  _Page(
    'My Passport',
    'Every new place you take a photo gets a stamp! Tap Map to see your stamps, and tap a stamp for a fun fact.',
    Gj.teal,
    () => const _Stamps(),
  ),
  _Page(
    'Word Jar',
    'New words go into your Word Jar. Tap a word to hear it.',
    Gj.teal,
    () => const _Pretend(child: BlobButton(icon: Icons.abc_rounded, color: Gj.teal, size: 100, label: 'Words', onTap: _nothing)),
  ),
  _Page(
    'Play games',
    'Tap Games to play with your photos and words. Win three stars!',
    Gj.kumkum,
    () => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pretend(child: BlobButton(icon: Icons.sports_esports_rounded, color: Gj.kumkum, size: 96, label: 'Games', onTap: _nothing)),
        SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: Gj.marigold, size: 48),
            Icon(Icons.star_rounded, color: Gj.marigold, size: 48),
            Icon(Icons.star_rounded, color: Gj.marigold, size: 48),
          ],
        ),
      ],
    ),
  ),
  _Page(
    'For grown-ups',
    'Grown-ups, hold the little lock for three seconds. You can turn sounds off, see progress, and save a backup.',
    Gj.inkSoft,
    () => const _Pretend(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, color: Gj.inkSoft, size: 80),
          Text('Hold for 3 seconds', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Gj.inkSoft)),
        ],
      ),
    ),
  ),
];

void _nothing() {}

/// How to Use: a picture book of the app, one step per page, read aloud by
/// Sheru. Opens by itself the first time; the Help button brings it back.
class HowToScreen extends StatefulWidget {
  const HowToScreen({super.key});

  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends State<HowToScreen> {
  final _pager = PageController();
  int _page = 0;

  App get _app => App.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  @override
  void deactivate() {
    _app.speaker.stop();
    _app.sounds.unhush();
    super.deactivate();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final p = _pages[_page];
    await _app.sounds.hush();
    await _app.speaker.say('${p.title}. ${p.say}');
    await _app.sounds.unhush();
  }

  void _go(int to) {
    if (to < 0) return;
    if (to >= _pages.length) {
      Navigator.of(context).pop();
      return;
    }
    _pager.animateToPage(to, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    final color = _pages[_page].color;
    return Scaffold(
      body: BandhaniBackground(
        color: Color.lerp(Gj.sand, color, 0.08)!,
        dot: color.withValues(alpha: 0.12),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    BlobButton(
                      icon: Icons.close_rounded,
                      color: Gj.inkSoft,
                      size: 52,
                      sound: Sfx.whoosh,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(child: Center(child: OutlinedTitle('How to Use', size: 28))),
                    BlobButton(icon: Icons.volume_up_rounded, color: Gj.teal, size: 52, onTap: _read),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: _pages.length,
                  onPageChanged: (i) {
                    _app.sounds.play(Sfx.whoosh);
                    setState(() => _page = i);
                    _read();
                  },
                  itemBuilder: (context, i) => _PageView(page: _pages[i], number: i + 1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: i == _page ? color : Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Gj.edge(color).withValues(alpha: 0.4), width: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Row(
                  children: [
                    BlobButton(
                      icon: Icons.arrow_back_rounded,
                      color: Gj.peacock,
                      size: 60,
                      onTap: _page == 0 ? null : () => _go(_page - 1),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KutchButton(
                        label: last ? "Let's go!" : 'Next',
                        icon: last ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                        color: last ? Gj.leaf : color,
                        height: 66,
                        onTap: () => _go(_page + 1),
                      ),
                    ),
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

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.number});
  final _Page page;
  final int number;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: page.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                child: Text('$number', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              OutlinedTitle(page.title, size: 36, color: Gj.edge(page.color)),
              const SizedBox(height: 18),
              SizedBox(height: 210, child: Center(child: page.picture())),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Sheru(size: 76),
                  const SizedBox(width: 4),
                  Flexible(child: SpeechBubble(page.say)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A real button shown as a picture: it looks right but does nothing.
class _Pretend extends StatelessWidget {
  const _Pretend({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: child);
}

class _FixAWord extends StatelessWidget {
  const _FixAWord();

  @override
  Widget build(BuildContext context) {
    return const _Pretend(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              WordBubble(word: 'I', color: Gj.kumkum),
              WordBubble(word: 'saw', color: Gj.marigold),
              WordBubble(word: 'a', color: Gj.peacock),
              WordBubble(word: 'camal', color: Gj.leaf, selected: true),
            ],
          ),
          SizedBox(height: 10),
          Icon(Icons.keyboard_double_arrow_down_rounded, color: Gj.peacock, size: 40),
          SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_rounded, color: Gj.inkSoft, size: 34),
              SizedBox(width: 10),
              WordBubble(word: 'camel', color: Gj.leaf),
            ],
          ),
        ],
      ),
    );
  }
}

class _SayMore extends StatelessWidget {
  const _SayMore();

  @override
  Widget build(BuildContext context) {
    return _Pretend(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final f in [Feeling.happy, Feeling.excited, Feeling.surprised, Feeling.tired])
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: FeelingFace(f, size: 56)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final s in Sense.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: BlobButton(icon: s.icon, color: s.color, size: 50, label: s.label, onTap: _nothing),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stamps extends StatelessWidget {
  const _Stamps();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PlaceStamp(placeById('gir')!, size: 100, tilt: -0.12),
        const SizedBox(width: 6),
        PlaceStamp(placeById('white_rann')!, size: 100, tilt: 0.08),
        const SizedBox(width: 6),
        PlaceStamp(placeById('rani_ki_vav')!, size: 100, inked: false, tilt: -0.04),
      ],
    );
  }
}

class _Bridge extends StatelessWidget {
  const _Bridge();

  @override
  Widget build(BuildContext context) {
    Widget chip(String native, String name) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Gj.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Gj.teal, width: 2.5),
      ),
      child: Column(
        children: [
          Text('$native → English', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Gj.teal)),
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Gj.inkSoft)),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Flexible(child: chip('বাংলা', 'Bengali')), const SizedBox(width: 10), Flexible(child: chip('हिंदी', 'Hindi'))],
        ),
        const SizedBox(height: 18),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('উট / ऊंट', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Gj.inkSoft)),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, color: Gj.teal, size: 32),
            SizedBox(width: 10),
            Text('camel', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Gj.teal)),
          ],
        ),
      ],
    );
  }
}
