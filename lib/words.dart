// Turning speech into word bubbles and back. Speech recognisers return plain
// lower-case words; the bubbles let the child fix one word without a keyboard.

List<String> splitWords(String text) => text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

String joinWords(List<String> words) => words.join(' ');

/// Swaps word [index] for whatever was said instead (which may be several
/// words, or none).
List<String> replaceWord(List<String> words, int index, String said) =>
    [...words.take(index), ...splitWords(said), ...words.skip(index + 1)];

List<String> removeWord(List<String> words, int index) => [...words.take(index), ...words.skip(index + 1)];

/// A capital at the start and a full stop at the end: the first small lesson
/// in what a sentence looks like.
String tidySentence(String text) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return t;
  var out = t[0].toUpperCase() + t.substring(1);
  out = out.replaceAllMapped(RegExp(r'\bi\b'), (_) => 'I');
  if (!RegExp(r'[.!?]$').hasMatch(out)) out = '$out.';
  return out;
}

/// Joins a run of recogniser segments, skipping empties.
String joinSegments(Iterable<String> parts) => parts.map((p) => p.trim()).where((p) => p.isNotEmpty).join(' ');
