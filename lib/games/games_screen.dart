import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../sound_board.dart';
import '../theme.dart';
import 'game_kit.dart';
import 'ispy_game.dart';
import 'kite_spell_game.dart';
import 'sentence_train_game.dart';
import 'which_photo_game.dart';

class _Game {
  const _Game(this.title, this.blurb, this.icon, this.color, this.open);
  final String title, blurb;
  final IconData icon;
  final Color color;
  final Widget Function() open;
}

final _games = [
  _Game('Which Photo?', 'Listen to Sheru and find the photo', Icons.hearing_rounded, Gj.peacock, () => const WhichPhotoGame()),
  _Game('Kite Spell', 'Catch letter kites to spell words', Icons.abc_rounded, Gj.saffron, () => const KiteSpellGame()),
  _Game('Sentence Train', 'Put the word carriages in order', Icons.train_rounded, Gj.leaf, () => const SentenceTrainGame()),
  _Game('Travel I-Spy', 'Find nine things on your trip', Icons.travel_explore_rounded, Gj.lilac, () => const ISpyGame()),
];

/// The games corner: four games made from the child's own diary.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Games',
      color: Gj.kumkum,
      sheruSays: "Let's play with your trip! Pick a game.",
      child: GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.82,
        children: [for (final g in _games) _GameCard(game: g)],
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  const _GameCard({required this.game});
  final _Game game;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        App.of(context).sounds.play(Sfx.whoosh);
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => g.open()));
      },
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(g.color, Colors.white, 0.25)!, g.color],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [BoxShadow(color: Gj.edge(g.color), offset: const Offset(0, 7))],
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: FittedBox(
                    child: Padding(padding: const EdgeInsets.all(8), child: Icon(g.icon, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                g.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.05,
                  shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 2)],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                g.blurb,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
