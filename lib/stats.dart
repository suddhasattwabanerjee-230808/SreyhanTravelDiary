import 'models.dart';
import 'words.dart';

/// Describing words a young traveller is likely to say: colours, sizes,
/// feelings, textures, tastes. Counted to show the child is describing
/// things, not just naming them.
const describingWords = {
  // Colours.
  'red', 'blue', 'green', 'yellow', 'orange', 'pink', 'purple', 'white', 'black', 'brown', 'grey', 'gray',
  'golden', 'silver', 'colourful', 'colorful', 'bright', 'dark', 'light',
  // Size and shape.
  'big', 'small', 'little', 'tiny', 'huge', 'giant', 'tall', 'short', 'long', 'wide', 'round', 'high', 'deep',
  'enormous', 'fat', 'thin',
  // Feel, look and sound.
  'soft', 'hard', 'rough', 'smooth', 'bumpy', 'wet', 'dry', 'hot', 'cold', 'warm', 'cool', 'sandy', 'shiny',
  'sparkly', 'loud', 'quiet', 'noisy', 'fast', 'slow', 'heavy', 'old', 'new', 'clean', 'dirty', 'windy', 'sunny',
  'cloudy', 'rainy', 'beautiful', 'pretty', 'ugly', 'cute', 'funny', 'strange', 'scary', 'busy', 'crowded',
  'peaceful', 'wild', 'fluffy', 'spiky', 'sticky', 'salty', 'sweet', 'spicy', 'sour', 'bitter', 'yummy',
  'tasty', 'delicious', 'juicy', 'crunchy', 'fresh',
  // Feelings and judgements.
  'happy', 'sad', 'excited', 'tired', 'calm', 'surprised', 'angry', 'scared', 'brave', 'proud', 'lucky',
  'amazing', 'awesome', 'wonderful', 'great', 'good', 'nice', 'lovely', 'best', 'favourite', 'favorite',
  'fun', 'boring', 'interesting', 'special', 'famous', 'friendly', 'kind', 'naughty', 'hungry', 'thirsty',
};

/// One diary day, in numbers, for the grown-ups' progress charts.
class DayStats {
  const DayStats(this.date, this.pictures, this.words, this.describing, this.newWords);
  final String date;
  final int pictures;

  /// Words the child said, across all of the day's pictures.
  final int words;

  /// Of those, describing words ([describingWords]).
  final int describing;

  /// English words learned from Bengali or Hindi for the first time that day.
  final int newWords;

  /// Average words per picture: how long the child's sentences are getting.
  double get sentenceLength => pictures == 0 ? 0 : words / pictures;
}

/// Stats for every day, oldest first.
List<DayStats> dayStats(List<DiaryDay> days) {
  final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
  final known = <String>{};
  return [
    for (final d in sorted)
      () {
        var words = 0, describing = 0, fresh = 0;
        for (final m in d.moments) {
          final said = splitWords(m.text).map(bareWord).where((w) => w.isNotEmpty);
          words += said.length;
          describing += said.where(describingWords.contains).length;
          for (final w in m.learned) {
            if (known.add(bareWord(w.word))) fresh++;
          }
        }
        return DayStats(d.date, d.moments.length, words, describing, fresh);
      }(),
  ];
}
