import 'dart:math';

import '../models.dart';
import '../vision.dart';
import '../words.dart';

/// Short words that make poor spelling practice.
const _stopWords = {
  'the', 'and', 'was', 'were', 'with', 'that', 'this', 'there', 'then', 'they', 'them', 'have', 'had', 'has',
  'from', 'into', 'very', 'went', 'what', 'when', 'where', 'which', 'who', 'you', 'your', 'our', 'are', 'for',
  'but', 'not', 'some', 'saw', 'see', 'got', 'its', 'also', 'just', 'like', 'over', 'their', 'here',
};

List<Moment> _allMoments(List<DiaryDay> days) => [for (final d in days) ...d.moments];

// --- Which Photo? -------------------------------------------------------------

class PhotoRound {
  const PhotoRound(this.answer, this.choices);
  final Moment answer;
  final List<Moment> choices;
}

/// Moments whose sentence is worth listening to.
List<Moment> listenableMoments(List<DiaryDay> days) =>
    _allMoments(days).where((m) => splitWords(m.text).length >= 3).toList();

/// Rounds of "which photo does Sheru's sentence belong to?". Each answer is a
/// different moment where possible; the other choices are random.
List<PhotoRound> photoRounds(List<Moment> moments, Random r, {int rounds = 5, int choices = 4}) {
  if (moments.length < 2) return const [];
  final answers = List.of(moments)..shuffle(r);
  return [
    for (final answer in answers.take(rounds))
      PhotoRound(
        answer,
        ([answer, ...(List.of(moments)..remove(answer)..shuffle(r)).take(choices - 1)])..shuffle(r),
      ),
  ];
}

// --- Kite Spell ---------------------------------------------------------------

class SpellWord {
  const SpellWord(this.word, this.photo);
  final String word;

  /// The photo it came from (relative path).
  final String photo;
}

bool _spellable(String w, {int min = 3, int max = 9}) => RegExp('^[a-z]{$min,$max}\$').hasMatch(w);

/// Words to spell, best first: words learned in Bengali/Hindi, then the
/// things the phone saw in the photos, then longer words the child said.
List<SpellWord> spellingWords(List<DiaryDay> days, Random r, {int count = 5}) {
  final seen = <String>{};
  final tiers = [<SpellWord>[], <SpellWord>[], <SpellWord>[]];
  for (final m in _allMoments(days)) {
    for (final w in m.learned) {
      final word = w.word.toLowerCase();
      if (_spellable(word) && seen.add(word)) tiers[0].add(SpellWord(word, m.photo));
    }
    for (final l in m.labels) {
      final word = l.toLowerCase();
      if (thingOf(word) != null && _spellable(word) && seen.add(word)) tiers[1].add(SpellWord(word, m.photo));
    }
    for (final raw in splitWords(m.text)) {
      final word = bareWord(raw);
      if (_spellable(word, min: 4, max: 8) && !_stopWords.contains(word) && seen.add(word)) {
        tiers[2].add(SpellWord(word, m.photo));
      }
    }
  }
  return [for (final t in tiers) ...(t..shuffle(r))].take(count).toList();
}

/// The word's letters in a muddle (never already in order, if avoidable).
List<String> scrambled(String word, Random r) {
  final letters = word.split('');
  if (letters.toSet().length < 2) return letters;
  List<String> out;
  do {
    out = List.of(letters)..shuffle(r);
  } while (out.join() == word);
  return out;
}

// --- Sentence Train -----------------------------------------------------------

/// Sentences short enough to rebuild, picked at random.
List<Moment> trainSentences(List<DiaryDay> days, Random r, {int count = 4}) {
  final ok = _allMoments(days).where((m) {
    final n = splitWords(m.text).length;
    return n >= 3 && n <= 9;
  }).toList()..shuffle(r);
  return ok.take(count).toList();
}

// --- Travel I-Spy -------------------------------------------------------------

/// The bingo card, row by row.
const spyCard = [
  Thing.animal, Thing.bird, Thing.tree, //
  Thing.water, Thing.building, Thing.ride, //
  Thing.food, Thing.sky, Thing.people,
];

const _lines = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
  [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
  [0, 4, 8], [2, 4, 6], // diagonals
];

/// For each kind of thing, the first photo of the day that shows it.
Map<Thing, Moment> spyFinds(DiaryDay day) {
  final found = <Thing, Moment>{};
  for (final m in day.moments) {
    for (final t in thingsIn(m.labels)) {
      found.putIfAbsent(t, () => m);
    }
  }
  return found;
}

/// How many full rows, columns or diagonals are found.
int bingoLines(Set<Thing> found) => _lines.where((l) => l.every((i) => found.contains(spyCard[i]))).length;

/// Stars for a game from mistakes made (or misses).
int starsFor(int mistakes, int rounds) {
  if (rounds == 0) return 0;
  if (mistakes <= rounds ~/ 4) return 3;
  if (mistakes <= rounds) return 2;
  return 1;
}
