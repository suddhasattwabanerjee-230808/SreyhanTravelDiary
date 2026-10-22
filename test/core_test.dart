import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sreyhan_diary/diary_store.dart';
import 'package:sreyhan_diary/games/game_logic.dart';
import 'package:sreyhan_diary/models.dart';
import 'package:sreyhan_diary/screens/word_jar_screen.dart';
import 'package:sreyhan_diary/translate.dart';
import 'package:sreyhan_diary/vision.dart';
import 'package:sreyhan_diary/words.dart';

Moment moment(String id, String text, {List<String> labels = const [], List<String> learned = const []}) => Moment(
  id: id,
  createdAt: DateTime(2026, 10, 22),
  photo: 'media/$id.jpg',
  text: text,
  labels: labels,
  learned: [for (final w in learned) LearnedWord(w, 'x', 'Hindi')],
);

void main() {
  group('words', () {
    test('split and join', () {
      expect(splitWords('  we saw   a camel '), ['we', 'saw', 'a', 'camel']);
      expect(joinWords(['a', 'big', 'camel']), 'a big camel');
    });

    test('replace one word with a fixed one, or several, or none', () {
      expect(replaceWord(['we', 'saw', 'a', 'camera'], 3, 'camel'), ['we', 'saw', 'a', 'camel']);
      expect(replaceWord(['we', 'saw', 'camel'], 2, 'a big camel'), ['we', 'saw', 'a', 'big', 'camel']);
      expect(replaceWord(['we', 'um', 'saw'], 1, '  '), ['we', 'saw']);
    });

    test('remove a word', () {
      expect(removeWord(['we', 'um', 'saw'], 1), ['we', 'saw']);
    });

    test('tidy into a sentence', () {
      expect(tidySentence('today i rode a camel'), 'Today I rode a camel.');
      expect(tidySentence('wow it was so tall!'), 'Wow it was so tall!');
      expect(tidySentence('   '), '');
      // "i" only on its own, not inside words.
      expect(tidySentence('it is big'), 'It is big.');
    });

    test('join recogniser segments', () {
      expect(joinSegments(['we saw', '', ' a camel ', '']), 'we saw a camel');
    });

    test('word spans line up with split words', () {
      final spans = wordSpans('We  saw a\ncamel!');
      expect(spans.map((s) => s.text), splitWords('We  saw a\ncamel!'));
      expect(spans.last.start, 10);
    });
  });

  group('photo questions', () {
    test('labels become kinds of things', () {
      expect(thingOf('Camel'), Thing.animal);
      expect(thingOf('Sunset'), Thing.sky);
      expect(thingOf('Hindu temple'), Thing.building);
      expect(thingOf('Flowers'), Thing.tree);
      expect(thingOf('Ice cream'), Thing.food);
      // Whole words only: "car" isn't in "carpet".
      expect(thingOf('Carpet'), isNull);
      expect(thingsIn(['Camel', 'Horse', 'Sky', 'Fun']), {Thing.animal, Thing.sky});
    });

    test('questions come from the first two things recognised', () {
      expect(photoQuestions(['Fun', 'Elephant', 'Horse', 'Sky', 'Boat']), [
        'I see an elephant! What colour was it?',
        'Was the elephant big or small?',
        'Look at the sky! What colours can you see?',
      ]);
      expect(photoQuestions(['Fun', 'Event']), isEmpty);
    });
  });

  test('translations are ready to drop into a sentence', () {
    expect(cleanTranslation('Camel.'), 'camel');
    expect(cleanTranslation(' Big elephant '), 'big elephant');
    expect(cleanTranslation('TV'), 'TV');
    expect(cleanTranslation('ऊंट।'), 'ऊंट');
  });

  group('models', () {
    test('day round-trips through JSON', () {
      final day = DiaryDay(
        date: '2026-10-22',
        moments: [
          Moment(
            id: 'a1',
            createdAt: DateTime(2026, 10, 22, 9, 30),
            photo: 'media/a1.jpg',
            text: 'We saw a camel.',
            labels: const ['Camel', 'Sand'],
            learned: const [LearnedWord('camel', 'উট', 'Bengali')],
            source: 'gallery',
          ),
        ],
      );
      final back = DiaryDay.fromJson(day.toJson()).moments.single;
      expect(back.text, 'We saw a camel.');
      expect(back.labels, ['Camel', 'Sand']);
      expect(back.learned.single.from, 'উট');
      expect(back.learned.single.language, 'Bengali');
      expect(back.source, 'gallery');
      expect(back.createdAt, DateTime(2026, 10, 22, 9, 30));
    });

    test('older days without labels still load', () {
      final m = Moment.fromJson({'id': 'x', 'createdAt': '2026-10-22T09:00:00.000', 'photo': 'p', 'text': 'Hi.', 'stars': 2});
      expect(m.labels, isEmpty);
      expect(m.learned, isEmpty);
    });

    test('dates', () {
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(prettyDate(DateTime(2026, 10, 22)), 'Thursday, 22 October');
      expect(shortDate(DateTime(2026, 10, 22)), '22 Oct');
    });
  });

  test('the word jar holds each learned word once, newest first', () {
    final jar = collectWords([
      DiaryDay(date: '2026-10-22', moments: [moment('a', '', learned: ['camel']), moment('b', '', learned: ['kite', 'Camel'])]),
      DiaryDay(date: '2026-10-21', moments: [moment('c', '', learned: ['river'])]),
    ]);
    expect(jar.map((j) => j.word.word), ['kite', 'Camel', 'river']);
    expect(jar.first.photo, 'media/b.jpg');
  });

  group('games', () {
    final r = Random(1);
    final days = [
      DiaryDay(
        date: '2026-10-22',
        moments: [
          moment('a', 'We rode a camel in the desert.', labels: ['Camel', 'Sky'], learned: ['kite']),
          moment('b', 'Big boats.', labels: ['Boat']),
          moment('c', 'The flamingos were pink!', labels: ['Bird', 'Water']),
        ],
      ),
      DiaryDay(date: '2026-10-21', moments: [moment('d', 'Hi.')]),
    ];

    test('which photo: every round has its answer among the choices', () {
      final moments = listenableMoments(days);
      expect(moments.map((m) => m.id), ['a', 'c']);
      final rounds = photoRounds(moments, r);
      expect(rounds, hasLength(2));
      for (final round in rounds) {
        expect(round.choices, contains(round.answer));
        expect(round.choices.toSet(), hasLength(round.choices.length));
      }
      expect(photoRounds(moments.take(1).toList(), r), isEmpty);
    });

    test('kite spell: learned words first, then photo things, then longer words said', () {
      final words = spellingWords(days, r, count: 10).map((w) => w.word).toList();
      expect(words.first, 'kite');
      expect(words.sublist(1, 6).toSet(), {'camel', 'sky', 'boat', 'bird', 'water'});
      expect(words, containsAll(['rode', 'desert', 'pink']));
      // Said words over 8 letters are too long to spell with kites.
      expect(words, isNot(contains('flamingos')));
      expect(words, isNot(contains('the')));
      expect(words, isNot(contains('hi')));
    });

    test('kite spell letters are always muddled', () {
      for (var i = 0; i < 20; i++) {
        final s = scrambled('camel', Random(i));
        expect(s.join(), isNot('camel'));
        expect(s.toList()..sort(), 'camel'.split('')..sort());
      }
      expect(scrambled('aa', r), ['a', 'a']);
    });

    test('sentence train uses sentences of 3 to 9 words', () {
      expect(trainSentences(days, r, count: 10).map((m) => m.id).toSet(), {'a', 'c'});
    });

    test('I-Spy stamps things from the day\'s photos and counts bingo lines', () {
      final found = spyFinds(days.first);
      expect(found.keys.toSet(), {Thing.animal, Thing.sky, Thing.ride, Thing.bird, Thing.water});
      expect(found[Thing.animal]!.id, 'a');
      expect(bingoLines({Thing.animal, Thing.bird, Thing.tree}), 1);
      expect(bingoLines({Thing.animal, Thing.building, Thing.people}), 1);
      expect(bingoLines(Thing.values.toSet()), 8);
      expect(bingoLines({Thing.animal, Thing.bird}), 0);
    });

    test('stars', () {
      expect(starsFor(0, 5), 3);
      expect(starsFor(3, 5), 2);
      expect(starsFor(9, 5), 1);
    });
  });

  group('store', () {
    late Directory tmp;
    late DiaryStore store;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('diary_test');
      store = DiaryStore(Directory('${tmp.path}/diary'));
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('adds moments to the right day and lists days newest first', () async {
      final photo = File('${tmp.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
      var notified = 0;
      store.addListener(() => notified++);

      for (final (i, at) in [DateTime(2026, 10, 20, 10), DateTime(2026, 10, 22, 9), DateTime(2026, 10, 22, 17)].indexed) {
        final id = 'm$i';
        await store.addMoment(
          Moment(id: id, createdAt: at, photo: await store.importPhoto(photo.path, id), text: 'Moment $i.'),
        );
      }

      final days = await store.allDays();
      expect(days.map((d) => d.date), ['2026-10-22', '2026-10-20']);
      expect(days.first.moments.map((m) => m.id), ['m1', 'm2']);
      expect(store.file('media/m1.jpg').readAsBytesSync(), [1, 2, 3]);
      expect(notified, 3);
    });

    test('deleting a moment removes its photo', () async {
      final photo = File('${tmp.path}/p.jpg')..writeAsBytesSync([1]);
      final rel = await store.importPhoto(photo.path, 'x');
      await store.addMoment(Moment(id: 'x', createdAt: DateTime(2026, 10, 22), photo: rel, text: 'Hi.'));

      await store.deleteMoment('2026-10-22', 'x');

      expect(await store.allDays(), isEmpty);
      expect(store.file(rel).existsSync(), isFalse);
    });

    test('an unreadable day file is skipped, not fatal', () async {
      Directory('${store.root.path}/days').createSync(recursive: true);
      File('${store.root.path}/days/2026-10-01.json').writeAsStringSync('{not json');
      expect(await store.allDays(), isEmpty);
    });
  });
}
