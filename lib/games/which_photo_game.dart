import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import 'game_kit.dart';
import 'game_logic.dart';

/// Which Photo? Sheru reads one of the child's own diary sentences; they tap
/// the photo it belongs to. Listening practice, and a trip down memory lane.
class WhichPhotoGame extends StatefulWidget {
  const WhichPhotoGame({super.key, this.seed});
  final int? seed;

  @override
  State<WhichPhotoGame> createState() => _WhichPhotoGameState();
}

class _WhichPhotoGameState extends State<WhichPhotoGame> {
  static const _color = Gj.peacock;
  late final _random = Random(widget.seed);
  List<PhotoRound>? _rounds;
  int _round = 0;
  int _misses = 0;
  final _wrong = <String>{};
  bool _solved = false;
  int _shakes = 0;

  App get _app => App.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rounds == null) _start();
  }

  Future<void> _start() async {
    final moments = listenableMoments(await _app.store.allDays());
    if (!mounted) return;
    setState(() {
      _rounds = photoRounds(moments, _random);
      _round = 0;
      _misses = 0;
      _wrong.clear();
      _solved = false;
    });
    _read();
  }

  void _read() {
    final rounds = _rounds;
    if (rounds == null || _round >= rounds.length) return;
    _app.speaker.say(rounds[_round].answer.text);
  }

  Future<void> _pick(PhotoRound r, String id) async {
    if (_solved || _wrong.contains(id)) return;
    if (id != r.answer.id) {
      _app.sounds.play(Sfx.oops);
      setState(() {
        _wrong.add(id);
        _misses++;
        _shakes++;
      });
      return;
    }
    _app.sounds.play(Sfx.sparkle);
    setState(() => _solved = true);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _round++;
      _wrong.clear();
      _solved = false;
    });
    _read();
  }

  @override
  void deactivate() {
    _app.speaker.stop();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final rounds = _rounds;
    if (rounds == null) return const GameShell(title: 'Which Photo?', color: _color, sheruSays: '...', child: SizedBox());
    if (rounds.isEmpty) {
      return const GameShell(
        title: 'Which Photo?',
        color: _color,
        sheruSays: 'Add two moments to your diary first, then we can play!',
        child: SizedBox(),
      );
    }
    if (_round >= rounds.length) {
      final stars = starsFor(_misses, rounds.length);
      return GameShell(
        title: 'Which Photo?',
        color: _color,
        sheruSays: gameOverMessage(stars),
        happy: true,
        child: GameOver(stars: stars, onAgain: _start),
      );
    }
    final r = rounds[_round];
    return GameShell(
      title: 'Which Photo?',
      color: _color,
      round: _round,
      rounds: rounds.length,
      happy: _solved,
      sheruSays: _solved ? 'Yes! That\'s the one!' : 'Listen! Which photo am I talking about?',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          Center(
            child: KutchButton(
              label: _solved ? r.answer.text : 'Hear it again',
              icon: Icons.volume_up_rounded,
              color: _solved ? Gj.leaf : _color,
              height: 64,
              fontSize: _solved ? 18 : 24,
              onTap: _read,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: [
              for (final m in r.choices)
                Shake(
                  shakes: _wrong.contains(m.id) ? _shakes : 0,
                  child: GestureDetector(
                    onTap: () => _pick(r, m.id),
                    child: _Choice(
                      photo: m.photo,
                      state: _solved && m.id == r.answer.id
                          ? _ChoiceState.right
                          : (_wrong.contains(m.id) ? _ChoiceState.wrong : _ChoiceState.open),
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

enum _ChoiceState { open, right, wrong }

class _Choice extends StatelessWidget {
  const _Choice({required this.photo, required this.state});
  final String photo;
  final _ChoiceState state;

  @override
  Widget build(BuildContext context) {
    final border = switch (state) {
      _ChoiceState.right => Gj.leaf,
      _ChoiceState.wrong => Gj.kumkum,
      _ChoiceState.open => Colors.white,
    };
    return AnimatedScale(
      scale: state == _ChoiceState.right ? 1.06 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 6),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: state == _ChoiceState.wrong ? 0.4 : 1, child: DiaryPhoto(photo, radius: 16)),
            if (state != _ChoiceState.open)
              Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: border,
                  child: Icon(
                    state == _ChoiceState.right ? Icons.check_rounded : Icons.close_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
