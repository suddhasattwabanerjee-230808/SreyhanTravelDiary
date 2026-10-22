import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../words.dart';
import 'game_kit.dart';
import 'game_logic.dart';

/// Sentence Train: one of the child's own diary sentences, jumbled into train
/// carriages. Tap them in order to couple them to the engine.
class SentenceTrainGame extends StatefulWidget {
  const SentenceTrainGame({super.key, this.seed});
  final int? seed;

  @override
  State<SentenceTrainGame> createState() => _SentenceTrainGameState();
}

class _SentenceTrainGameState extends State<SentenceTrainGame> {
  static const _color = Gj.leaf;
  late final _random = Random(widget.seed);
  List<Moment>? _trains;
  int _round = 0;
  int _mistakes = 0;
  List<String> _words = const [];
  List<int> _yard = const [];
  final _coupled = <int>[];
  int? _wrong;
  int _shakes = 0;
  bool _done = false;

  App get _app => App.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trains == null) _start();
  }

  Future<void> _start() async {
    final trains = trainSentences(await _app.store.allDays(), _random);
    if (!mounted) return;
    setState(() {
      _trains = trains;
      _round = 0;
      _mistakes = 0;
    });
    _newTrain();
  }

  void _newTrain() {
    if (_trains == null || _round >= _trains!.length) return;
    final words = splitWords(_trains![_round].text);
    final order = [for (var i = 0; i < words.length; i++) i];
    do {
      order.shuffle(_random);
    } while (order.length > 1 && _inOrder(order));
    setState(() {
      _words = words;
      _yard = order;
      _coupled.clear();
      _done = false;
      _wrong = null;
    });
  }

  bool _inOrder(List<int> order) => [for (var i = 0; i < order.length; i++) order[i] == i].every((b) => b);

  void _tap(int i) {
    if (_done || _coupled.contains(i)) return;
    // Any carriage with the right word will do, even if the word appears twice.
    if (bareWord(_words[i]) != bareWord(_words[_coupled.length])) {
      _app.sounds.play(Sfx.oops);
      setState(() {
        _mistakes++;
        _wrong = i;
        _shakes++;
      });
      return;
    }
    _app.sounds.play(Sfx.pop);
    setState(() {
      _coupled.add(i);
      _wrong = null;
    });
    if (_coupled.length == _words.length) _finish();
  }

  Future<void> _finish() async {
    setState(() => _done = true);
    _app.sounds.play(Sfx.whoosh);
    await _app.speaker.say(_trains![_round].text);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _round++);
    _newTrain();
  }

  @override
  void deactivate() {
    _app.speaker.stop();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final trains = _trains;
    if (trains == null) return const GameShell(title: 'Sentence Train', color: _color, sheruSays: '...', child: SizedBox());
    if (trains.isEmpty) {
      return const GameShell(
        title: 'Sentence Train',
        color: _color,
        sheruSays: 'Tell me about a photo first, then your words can ride the train!',
        child: SizedBox(),
      );
    }
    if (_round >= trains.length) {
      final stars = starsFor(_mistakes, trains.length * 2);
      return GameShell(
        title: 'Sentence Train',
        color: _color,
        sheruSays: gameOverMessage(stars),
        happy: true,
        child: GameOver(stars: stars, onAgain: _start),
      );
    }
    return GameShell(
      title: 'Sentence Train',
      color: _color,
      round: _round,
      rounds: trains.length,
      happy: _done,
      sheruSays: _done ? 'Choo choo! All aboard!' : 'Which word comes next? Fix the train!',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SizedBox(height: 120, child: DiaryPhoto(trains[_round].photo)),
          const SizedBox(height: 18),
          // The train so far, pulling away when it's complete.
          AnimatedSlide(
            offset: _done ? const Offset(0.04, 0) : Offset.zero,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            child: Wrap(
              spacing: 4,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                const _Engine(),
                for (final i in _coupled) _Carriage(word: _words[i], color: Gj.festive[i % Gj.festive.length]),
                if (!_done) _Carriage(word: '?', color: Colors.white, empty: true),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 6, decoration: BoxDecoration(color: Gj.inkSoft.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 26),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final i in _yard)
                if (!_coupled.contains(i))
                  Shake(
                    shakes: _wrong == i ? _shakes : 0,
                    child: GestureDetector(
                      onTap: () => _tap(i),
                      child: _Carriage(word: _words[i], color: Gj.festive[i % Gj.festive.length], big: true),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Engine extends StatelessWidget {
  const _Engine();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Gj.kumkum,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(6),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(Icons.train_rounded, color: Colors.white, size: 30),
        ),
        const _Wheels(),
      ],
    );
  }
}

class _Carriage extends StatelessWidget {
  const _Carriage({required this.word, required this.color, this.big = false, this.empty = false});
  final String word;
  final Color color;
  final bool big, empty;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: big ? 16 : 10, vertical: big ? 8 : 6),
          decoration: BoxDecoration(
            color: empty ? Colors.white.withValues(alpha: 0.5) : color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: empty ? Gj.inkSoft : Colors.white, width: 3),
            boxShadow: empty ? null : [BoxShadow(color: Gj.edge(color), offset: const Offset(0, 3))],
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: big ? 24 : 20,
              fontWeight: FontWeight.w800,
              color: empty ? Gj.inkSoft : Colors.white,
              height: 1.15,
            ),
          ),
        ),
        const _Wheels(),
      ],
    );
  }
}

class _Wheels extends StatelessWidget {
  const _Wheels();

  @override
  Widget build(BuildContext context) {
    Widget wheel() => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: Gj.ink, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [wheel(), const SizedBox(width: 14), wheel()]),
    );
  }
}
