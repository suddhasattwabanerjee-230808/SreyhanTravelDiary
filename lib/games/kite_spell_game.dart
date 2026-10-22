import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import '../widgets/sky.dart';
import 'game_kit.dart';
import 'game_logic.dart';

/// Kite Spell: the letters of a word from the trip fly as kites; tap them in
/// order to spell it. Only the right next letter sticks, so every word ends
/// spelled correctly.
class KiteSpellGame extends StatefulWidget {
  const KiteSpellGame({super.key, this.seed});
  final int? seed;

  @override
  State<KiteSpellGame> createState() => _KiteSpellGameState();
}

class _KiteSpellGameState extends State<KiteSpellGame> {
  static const _color = Gj.saffron;
  late final _random = Random(widget.seed);
  List<SpellWord>? _words;
  int _round = 0;
  int _typed = 0;
  int _mistakes = 0;
  List<String> _kites = const [];
  final _used = <int>{};
  int? _wrongKite;
  int _shakes = 0;
  bool _done = false;

  App get _app => App.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_words == null) _start();
  }

  Future<void> _start() async {
    final words = spellingWords(await _app.store.allDays(), _random);
    if (!mounted) return;
    setState(() {
      _words = words;
      _round = 0;
      _mistakes = 0;
    });
    _newWord();
  }

  String get _word => _words![_round].word;

  void _newWord() {
    if (_words == null || _round >= _words!.length) return;
    setState(() {
      _kites = scrambled(_word, _random);
      _used.clear();
      _typed = 0;
      _done = false;
      _wrongKite = null;
    });
    _app.speaker.say(_word);
  }

  void _tapKite(int i) {
    if (_done || _used.contains(i)) return;
    if (_kites[i] != _word[_typed]) {
      _app.sounds.play(Sfx.oops);
      setState(() {
        _mistakes++;
        _wrongKite = i;
        _shakes++;
      });
      return;
    }
    _app.sounds.play(Sfx.pop);
    setState(() {
      _used.add(i);
      _typed++;
      _wrongKite = null;
    });
    if (_typed == _word.length) _finishWord();
  }

  /// Puts the next letter in for the child (it counts as a mistake).
  void _hint() {
    if (_done) return;
    final i = [for (var k = 0; k < _kites.length; k++) k].firstWhere((k) => !_used.contains(k) && _kites[k] == _word[_typed]);
    _mistakes++;
    _tapKite(i);
  }

  Future<void> _finishWord() async {
    setState(() => _done = true);
    _app.sounds.play(Sfx.sparkle);
    await _app.speaker.say('$_word! ${_word.split('').join(', ')}. $_word!');
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _round++);
    _newWord();
  }

  @override
  void deactivate() {
    _app.speaker.stop();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    if (words == null) return const GameShell(title: 'Kite Spell', color: _color, sheruSays: '...', child: SizedBox());
    if (words.isEmpty) {
      return const GameShell(
        title: 'Kite Spell',
        color: _color,
        sheruSays: 'Tell me about some photos first, then we can spell your words!',
        child: SizedBox(),
      );
    }
    if (_round >= words.length) {
      final stars = starsFor(_mistakes, words.length * 2);
      return GameShell(
        title: 'Kite Spell',
        color: _color,
        sheruSays: gameOverMessage(stars),
        happy: true,
        child: GameOver(stars: stars, onAgain: _start),
      );
    }
    final w = words[_round];
    return GameShell(
      title: 'Kite Spell',
      color: _color,
      round: _round,
      rounds: words.length,
      happy: _done,
      sheruSays: _done ? 'You spelled "${w.word}"!' : 'Catch the kites to spell the word!',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          Row(
            children: [
              SizedBox(width: 110, height: 82, child: DiaryPhoto(w.photo, radius: 14)),
              const SizedBox(width: 14),
              BlobButton(icon: Icons.volume_up_rounded, color: Gj.teal, size: 54, label: 'Hear it', onTap: () => _app.speaker.say(w.word)),
              const SizedBox(width: 14),
              BlobButton(icon: Icons.lightbulb_rounded, color: Gj.marigold, size: 54, label: 'Help', onTap: _done ? null : _hint),
            ],
          ),
          const SizedBox(height: 18),
          _Slots(word: w.word, typed: _typed, done: _done),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _kites.length; i++)
                AnimatedOpacity(
                  opacity: _used.contains(i) ? 0.15 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: Shake(
                    shakes: _wrongKite == i ? _shakes : 0,
                    child: FlyingKite(
                      width: 78,
                      badge: 0.56,
                      color: Gj.festive[i % Gj.festive.length],
                      accent: Gj.festive[(i + 3) % Gj.festive.length],
                      phase: i * 0.23,
                      onTap: () => _tapKite(i),
                      child: Text(
                        _kites[i],
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Gj.edge(Gj.festive[i % Gj.festive.length])),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The word's letter boxes, filling in as the kites are caught.
class _Slots extends StatelessWidget {
  const _Slots({required this.word, required this.typed, required this.done});
  final String word;
  final int typed;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < word.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i < typed ? (done ? Gj.leaf : Colors.white) : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: i == typed && !done ? Gj.marigold : Gj.saffron, width: i == typed && !done ? 4 : 2.5),
            ),
            child: Text(
              i < typed ? word[i] : '',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: done ? Colors.white : Gj.ink, height: 1.1),
            ),
          ),
      ],
    );
  }
}
