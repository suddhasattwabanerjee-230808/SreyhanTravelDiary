import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/photo.dart';
import '../widgets/playful.dart';
import '../widgets/sentence_view.dart';
import '../widgets/sheru.dart';

/// The frame every game shares: back button, title, round dots and Sheru.
class GameShell extends StatelessWidget {
  const GameShell({
    super.key,
    required this.title,
    required this.color,
    required this.sheruSays,
    required this.child,
    this.round,
    this.rounds,
    this.happy = false,
  });

  final String title;
  final Color color;
  final String sheruSays;
  final Widget child;
  final int? round, rounds;
  final bool happy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BandhaniBackground(
        color: Color.lerp(Gj.sand, color, 0.08)!,
        dot: color.withValues(alpha: 0.13),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    BlobButton(
                      icon: Icons.arrow_back_rounded,
                      color: Gj.peacock,
                      size: 56,
                      sound: Sfx.whoosh,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Expanded(child: Center(child: OutlinedTitle(title, size: 28, color: Gj.edge(color)))),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              if (round != null && rounds != null) ...[const SizedBox(height: 6), RoundDots(round!, rounds!, color: color)],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: SheruSays(sheruSays, size: 76, happy: happy),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// One dot per round: done, current, still to come.
class RoundDots extends StatelessWidget {
  const RoundDots(this.round, this.rounds, {super.key, required this.color});
  final int round, rounds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < rounds; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == round ? 26 : 12,
            height: 12,
            decoration: BoxDecoration(
              color: i < round ? color : (i == round ? Gj.marigold : Colors.white),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Gj.edge(color).withValues(alpha: 0.5), width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// The end of a game: stars, and play again or back to the games.
class GameOver extends StatefulWidget {
  const GameOver({super.key, required this.stars, required this.onAgain});
  final int stars;
  final VoidCallback onAgain;

  @override
  State<GameOver> createState() => _GameOverState();
}

class _GameOverState extends State<GameOver> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = App.of(context);
      app.sounds.play(Sfx.dhol);
      if (widget.stars == 3) ConfettiBurst.show(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarRow(widget.stars, size: 72),
            const SizedBox(height: 28),
            KutchButton(label: 'Play again', icon: Icons.replay_rounded, color: Gj.leaf, onTap: widget.onAgain),
            const SizedBox(height: 16),
            KutchButton(
              label: 'More games',
              icon: Icons.sports_esports_rounded,
              color: Gj.peacock,
              sound: Sfx.whoosh,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

String gameOverMessage(int stars) => switch (stars) {
  3 => 'Amazing! Three stars!',
  2 => 'Great playing! Two stars!',
  _ => 'Good try! Play again for more stars!',
};

/// Shakes its child sideways whenever [shakes] goes up: "not that one".
class Shake extends StatelessWidget {
  const Shake({super.key, required this.shakes, required this.child});
  final int shakes;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(shakes),
      tween: Tween(begin: shakes == 0 ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, t, child) => Transform.translate(offset: Offset(sin(t * pi * 6) * 10 * (1 - t), 0), child: child),
      child: child,
    );
  }
}

/// A rounded photo from the diary.
class DiaryPhoto extends StatelessWidget {
  const DiaryPhoto(this.relativePath, {super.key, this.radius = 18});
  final String relativePath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedPhoto(FileImage(App.of(context).store.file(relativePath))),
    );
  }
}
