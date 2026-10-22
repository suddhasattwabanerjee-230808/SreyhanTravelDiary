import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sreyhan_diary/coach.dart';
import 'package:sreyhan_diary/diary_store.dart';
import 'package:sreyhan_diary/models.dart';
import 'package:sreyhan_diary/screens/word_jar_screen.dart';
import 'package:sreyhan_diary/words.dart';

void main() {
  group('words', () {
    test('split and join', () {
      expect(splitWords('  we saw   a camel '), ['we', 'saw', 'a', 'camel']);
      expect(joinWords(['a', 'big', 'camel']), 'a big camel');
    });

    test('replace one word with what was said again', () {
      expect(replaceWord(['we', 'saw', 'a', 'camera'], 3, 'camel'), ['we', 'saw', 'a', 'camel']);
      expect(replaceWord(['we', 'saw', 'camel'], 2, 'a big camel'), ['we', 'saw', 'a', 'big', 'camel']);
      expect(replaceWord(['we', 'um', 'saw'], 1, ''), ['we', 'saw']);
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
  });

  group('reading back', () {
    const target = 'I rode a tall, brown camel.';

    test('reading it all earns three stars and lights every word', () {
      final r = scoreReading(target, 'i rode a tall brown camel');
      expect(r.stars, 3);
      expect(r.all, isTrue);
    });

    test('a skipped or misheard word costs only itself', () {
      final r = scoreReading(target, 'I rode a tall brown camera');
      expect(r.matched, [true, true, true, true, true, false]);
      expect(r.stars, 2);
    });

    test('each heard word counts once', () {
      final r = scoreReading('the cat and the dog', 'the cat');
      expect(r.matched, [true, true, false, false, false]);
      expect(r.stars, 1);
    });

    test('nothing read, no stars', () {
      expect(scoreReading(target, 'hello').stars, 0);
    });

    test('word spans line up with split words', () {
      final spans = wordSpans('We  saw a\ncamel!');
      expect(spans.map((s) => s.text), splitWords('We  saw a\ncamel!'));
      expect(spans.last.start, 10);
    });
  });

  group('coach client', () {
    late List<Map<String, dynamic>> sent;
    HttpCoach coachReplying(int status, Object body) {
      sent = [];
      final client = MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer tok');
        sent.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(body), status);
      });
      return HttpCoach('https://coach.test', 'tok', client: client, photoBytes: (_) async => [1, 2, 3]);
    }

    test('asks with the photo and returns the questions', () async {
      final coach = coachReplying(200, {'praise': 'Wow!', 'questions': ['What colour?', ' ', 'Was it big?']});
      final q = await coach.ask('p.jpg', 'a camel');
      expect(q!.praise, 'Wow!');
      expect(q.questions, ['What colour?', 'Was it big?']);
      expect(sent.single, {'action': 'ask', 'said': 'a camel', 'image': base64Encode([1, 2, 3])});
    });

    test('keeps only new words that are really in the sentence', () async {
      final coach = coachReplying(200, {
        'praise': 'Great!',
        'sentences': ['I rode a tall camel.', 'It was fun.'],
        'newWords': [
          {'word': 'tall', 'meaning': 'very high'},
          {'word': 'enormous', 'meaning': 'very big'},
        ],
      });
      final s = await coach.polish('p.jpg', 'camel ride');
      expect(s!.text, 'I rode a tall camel. It was fun.');
      expect(s.newWords.map((w) => w.word), ['tall']);
    });

    test('any failure means null, so the screens go offline', () async {
      expect(await coachReplying(503, {'error': 'busy'}).ask('p.jpg', 'hi'), isNull);
      expect(await coachReplying(200, {'questions': []}).ask('p.jpg', 'hi'), isNull);
      expect(await coachReplying(200, {'english': ''}).bridge('oont'), isNull);
      expect(HttpCoach('', '').online, isFalse);
      expect(await HttpCoach('', '').bridge('oont'), isNull);
    });

    test('offline polish just tidies the words', () {
      expect(offlinePolish('we saw a camel').text, 'We saw a camel.');
      expect(offlinePolish('we saw a camel').newWords, isEmpty);
    });
  });

  test('the word jar holds each word once, newest first', () {
    Moment m(String id, List<String> words) => Moment(
      id: id,
      createdAt: DateTime(2026, 10, 22),
      photo: 'media/$id.jpg',
      text: '',
      newWords: [for (final w in words) NewWord(w, '')],
    );
    final jar = collectWords([
      DiaryDay(date: '2026-10-22', moments: [m('a', ['tall']), m('b', ['shiny', 'Tall'])]),
      DiaryDay(date: '2026-10-21', moments: [m('c', ['huge'])]),
    ]);
    expect(jar.map((j) => j.word.word), ['shiny', 'Tall', 'huge']);
    expect(jar.first.photo, 'media/b.jpg');
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
            superSentence: 'We saw a tall camel.',
            newWords: const [NewWord('tall', 'very high')],
            stars: 2,
            source: 'gallery',
          ),
        ],
      );
      final back = DiaryDay.fromJson(day.toJson());
      expect(back.date, day.date);
      expect(back.moments.single.text, 'We saw a camel.');
      expect(back.moments.single.source, 'gallery');
      expect(back.moments.single.pageText, 'We saw a tall camel.');
      expect(back.moments.single.newWords.single.meaning, 'very high');
      expect(back.moments.single.stars, 2);
      expect(back.moments.single.createdAt, DateTime(2026, 10, 22, 9, 30));
    });

    test('dates', () {
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(prettyDate(DateTime(2026, 10, 22)), 'Thursday, 22 October');
      expect(shortDate(DateTime(2026, 10, 22)), '22 Oct');
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
