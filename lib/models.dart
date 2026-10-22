/// A word Sheru taught, with a child-friendly meaning.
class NewWord {
  const NewWord(this.word, this.meaning);
  final String word;
  final String meaning;

  Map<String, dynamic> toJson() => {'word': word, 'meaning': meaning};

  factory NewWord.fromJson(Map<String, dynamic> j) => NewWord(j['word'] as String, (j['meaning'] as String?) ?? '');
}

/// One photo and what the child said about it.
class Moment {
  const Moment({
    required this.id,
    required this.createdAt,
    required this.photo,
    required this.text,
    this.superSentence,
    this.newWords = const [],
    this.stars = 0,
    this.source = 'camera',
  });

  final String id;
  final DateTime createdAt;

  /// Paths are relative to the diary folder, so a backup can move phones.
  final String photo;

  /// The child's own words.
  final String text;

  /// Sheru's polished version of [text], which the child read back.
  final String? superSentence;
  final List<NewWord> newWords;

  /// 0 to 3, for reading the Super Sentence aloud.
  final int stars;

  /// 'camera' or 'gallery'.
  final String source;

  /// What the diary page shows: the Super Sentence when there is one.
  String get pageText => superSentence ?? text;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'photo': photo,
    'text': text,
    if (superSentence != null) 'superSentence': superSentence,
    if (newWords.isNotEmpty) 'newWords': [for (final w in newWords) w.toJson()],
    if (stars > 0) 'stars': stars,
    'source': source,
  };

  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
    id: j['id'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    photo: j['photo'] as String,
    text: (j['text'] as String?) ?? '',
    superSentence: j['superSentence'] as String?,
    newWords: [for (final w in (j['newWords'] as List? ?? const [])) NewWord.fromJson(w as Map<String, dynamic>)],
    stars: (j['stars'] as num?)?.toInt() ?? 0,
    source: (j['source'] as String?) ?? 'camera',
  );
}

/// A diary day: every moment from one calendar date.
class DiaryDay {
  const DiaryDay({required this.date, this.moments = const []});

  /// yyyy-mm-dd.
  final String date;
  final List<Moment> moments;

  DateTime get day => DateTime.parse(date);
  bool get isEmpty => moments.isEmpty;

  DiaryDay copyWith({List<Moment>? moments}) => DiaryDay(date: date, moments: moments ?? this.moments);

  Map<String, dynamic> toJson() => {'version': 1, 'date': date, 'moments': [for (final m in moments) m.toJson()]};

  factory DiaryDay.fromJson(Map<String, dynamic> j) => DiaryDay(
    date: j['date'] as String,
    moments: [for (final m in (j['moments'] as List? ?? const [])) Moment.fromJson(m as Map<String, dynamic>)],
  );
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Thursday, 22 October".
String prettyDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// "22 Oct".
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)}';
