/// An English word the child found by saying it in Bengali or Hindi.
class LearnedWord {
  const LearnedWord(this.word, this.from, this.language);

  /// The English.
  final String word;

  /// What the child said, as speech-to-text wrote it (Bengali or Hindi script).
  final String from;

  /// 'Bengali' or 'Hindi'.
  final String language;

  Map<String, dynamic> toJson() => {'word': word, 'from': from, 'language': language};

  factory LearnedWord.fromJson(Map<String, dynamic> j) =>
      LearnedWord(j['word'] as String, (j['from'] as String?) ?? '', (j['language'] as String?) ?? '');
}

/// One photo and what the child said about it.
class Moment {
  const Moment({
    required this.id,
    required this.createdAt,
    required this.photo,
    required this.text,
    this.labels = const [],
    this.learned = const [],
    this.source = 'camera',
    this.feeling,
    this.place,
    this.editedAt,
  });

  final String id;
  final DateTime createdAt;

  /// Paths are relative to the diary folder, so a backup can move phones.
  final String photo;

  /// The child's words.
  final String text;

  /// What's in the photo, as the phone recognised it ("Camel", "Sky").
  final List<String> labels;

  /// Words translated into English while talking about this photo.
  final List<LearnedWord> learned;

  /// 'camera' or 'gallery'.
  final String source;

  /// How the child felt, a [Feeling] name ('happy', 'excited'...), if picked.
  final String? feeling;

  /// Where the photo was taken, a place id from places.dart, if known.
  final String? place;

  /// When the words were last changed by hand, if ever. Sync uses it to
  /// carry the newest wording to every phone.
  final DateTime? editedAt;

  /// The same entry with new words.
  Moment withText(String text, DateTime editedAt) => Moment(
    id: id,
    createdAt: createdAt,
    photo: photo,
    text: text,
    labels: labels,
    learned: learned,
    source: source,
    feeling: feeling,
    place: place,
    editedAt: editedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'photo': photo,
    'text': text,
    if (labels.isNotEmpty) 'labels': labels,
    if (learned.isNotEmpty) 'learned': [for (final w in learned) w.toJson()],
    'source': source,
    'feeling': ?feeling,
    'place': ?place,
    if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
  };

  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
    id: j['id'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    photo: j['photo'] as String,
    text: (j['text'] as String?) ?? '',
    labels: [for (final l in (j['labels'] as List? ?? const [])) l as String],
    learned: [for (final w in (j['learned'] as List? ?? const [])) LearnedWord.fromJson(w as Map<String, dynamic>)],
    source: (j['source'] as String?) ?? 'camera',
    feeling: j['feeling'] as String?,
    place: j['place'] as String?,
    editedAt: DateTime.tryParse((j['editedAt'] as String?) ?? ''),
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
