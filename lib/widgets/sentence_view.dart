import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../words.dart';

/// A sentence in big friendly type: learned words in a marigold highlight and
/// the word being read aloud lit up.
class SentenceView extends StatelessWidget {
  const SentenceView({
    super.key,
    required this.text,
    this.learned = const [],
    this.speaking,
    this.size = 26,
  });

  final String text;
  final List<LearnedWord> learned;

  /// Character range being spoken right now.
  final (int, int)? speaking;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fresh = {for (final w in learned) ...splitWords(w.word).map(bareWord)};
    final spans = <InlineSpan>[];
    final words = wordSpans(text);
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final isNew = fresh.contains(bareWord(w.text));
      final isSpoken = speaking != null && w.start < speaking!.$2 && w.end > speaking!.$1;
      spans.add(
        TextSpan(
          text: w.text,
          style: TextStyle(
            color: isSpoken ? Gj.kumkum : Gj.ink,
            background: isSpoken
                ? (Paint()..color = const Color(0x55FFD54F))
                : isNew
                ? (Paint()..color = const Color(0x40FFB300))
                : null,
            decoration: isNew ? TextDecoration.underline : null,
            decorationColor: Gj.saffron,
            decorationThickness: 2.5,
          ),
        ),
      );
      if (i < words.length - 1) spans.add(const TextSpan(text: ' '));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.35),
    );
  }
}

/// A learned word and what the child said for it, as a tappable chip.
class LearnedWordChip extends StatelessWidget {
  const LearnedWordChip({super.key, required this.word, this.onTap, this.color = Gj.saffron});
  final LearnedWord word;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 2.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_up_rounded, size: 20, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: word.word,
                      style: TextStyle(fontWeight: FontWeight.w800, color: Gj.edge(color)),
                    ),
                    if (word.from.isNotEmpty) TextSpan(text: '  ${word.from}'),
                  ],
                ),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Gj.ink, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three stars, filled up to [stars].
class StarRow extends StatelessWidget {
  const StarRow(this.stars, {super.key, this.size = 40});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          TweenAnimationBuilder<double>(
            key: ValueKey('star$i${i < stars}'),
            tween: Tween(begin: i < stars ? 0.2 : 1, end: 1),
            duration: Duration(milliseconds: 500 + i * 180),
            curve: Curves.elasticOut,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < stars ? Gj.marigold : const Color(0xFFCFC8DE),
              shadows: i < stars ? const [Shadow(color: Color(0x55B26A00), offset: Offset(0, 2))] : null,
            ),
          ),
      ],
    );
  }
}
