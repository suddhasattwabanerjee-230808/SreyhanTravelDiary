import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../diary_store.dart';
import '../games/games_screen.dart';
import '../models.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';
import '../widgets/sky.dart';
import 'day_screen.dart';
import 'moment_screen.dart';
import 'word_jar_screen.dart';

const childName = 'Sreyhan';

/// The Sky of Kites: today's big kite to fill, and every earlier day as a
/// kite flying behind it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DiaryStore? _store;
  List<DiaryDay> _days = const [];
  int _greeting = 0;

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

  @override
  void dispose() {
    _store?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final days = await _store!.allDays();
    if (mounted) setState(() => _days = days);
  }

  String get _today => dateKey(_app.now());

  DiaryDay get _todayDay => _days.firstWhere((d) => d.date == _today, orElse: () => DiaryDay(date: _today));

  List<DiaryDay> get _earlier => _days.where((d) => d.date != _today).toList();

  String get _sheruSays {
    final n = _todayDay.moments.length;
    final greetings = [
      'Hello, $childName! What did you see today?',
      'Take a photo and tell me all about it!',
      "Let's fill today's kite with pictures!",
      if (_earlier.isNotEmpty) 'Tap an old kite to read that day again!',
    ];
    if (n > 0 && _greeting == 0) return 'Wow, $n ${n == 1 ? 'picture' : 'pictures'} today! Want to add more?';
    return greetings[_greeting % greetings.length];
  }

  Future<void> _addMoment() async {
    await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const MomentScreen()));
  }

  void _openJar() {
    _app.sounds.play(Sfx.whoosh);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WordJarScreen()));
  }

  void _openDay(String date) {
    _app.sounds.play(Sfx.whoosh);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DayScreen(date: date)));
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayDay;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: SkyScene(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const RainbowTitle("$childName's", size: 30),
                          const RainbowTitle('Travel Diary', size: 38),
                          const SizedBox(height: 2),
                          OutlinedTitle(prettyDate(_app.now()), size: 18, color: Gj.inkSoft, stroke: 5),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _MusicToggle(sounds: _app.sounds),
                        const SizedBox(height: 10),
                        _JarButton(count: collectWords(_days).length, onTap: _openJar),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Spacer(),
                    FlyingKite(
                      width: (width * 0.42).clamp(140.0, 210.0),
                      color: Gj.kumkum,
                      accent: Gj.marigold,
                      glow: today.isEmpty,
                      onTap: today.isEmpty ? _addMoment : () => _openDay(today.date),
                      child: today.isEmpty
                          ? const Icon(Icons.add_rounded, size: 52, color: Gj.kumkum)
                          : Text(
                              '${today.moments.length}',
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Gj.kumkum, height: 1),
                            ),
                    ),
                    const OutlinedTitle('Today', size: 24, color: Gj.kumkum),
                    const Spacer(),
                    if (_earlier.isNotEmpty) _earlierKites(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                child: GestureDetector(
                  onTap: () {
                    _app.sounds.play(Sfx.pop);
                    setState(() => _greeting++);
                  },
                  child: SheruSays(_sheruSays, size: 104),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: KutchButton(label: 'Add a picture', icon: Icons.add_a_photo_rounded, onTap: _addMoment),
                    ),
                    const SizedBox(width: 12),
                    BlobButton(
                      icon: Icons.sports_esports_rounded,
                      color: Gj.kumkum,
                      size: 66,
                      label: 'Games',
                      sound: Sfx.whoosh,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GamesScreen())),
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

  Widget _earlierKites() {
    final days = _earlier;
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final d = days[i];
          final c = Gj.festive[(i + 2) % Gj.festive.length];
          final a = Gj.festive[(i + 5) % Gj.festive.length];
          return Column(
            children: [
              FlyingKite(
                width: 70,
                color: c,
                accent: a,
                phase: i * 0.37,
                onTap: () => _openDay(d.date),
                child: Text(
                  '${d.moments.length}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c, height: 1.1),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -26),
                child: OutlinedTitle(shortDate(d.day), size: 16, stroke: 5),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MusicToggle extends StatelessWidget {
  const _MusicToggle({required this.sounds});
  final SoundBoard sounds;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sounds,
      builder: (context, _) => BlobButton(
        icon: sounds.musicOn ? Icons.music_note_rounded : Icons.music_off_rounded,
        color: sounds.musicOn ? Gj.lilac : Gj.inkSoft,
        size: 54,
        onTap: () => sounds.setMusicOn(!sounds.musicOn),
      ),
    );
  }
}

/// Opens the Word Jar; the badge counts the words in it.
class _JarButton extends StatelessWidget {
  const _JarButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        BlobButton(icon: Icons.abc_rounded, color: Gj.teal, size: 54, label: 'Words', onTap: onTap),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: Gj.kumkum,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}
