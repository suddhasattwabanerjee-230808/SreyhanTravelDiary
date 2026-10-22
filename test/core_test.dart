import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sreyhan_diary/diary_store.dart';
import 'package:sreyhan_diary/models.dart';
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
            source: 'gallery',
          ),
        ],
      );
      final back = DiaryDay.fromJson(day.toJson());
      expect(back.date, day.date);
      expect(back.moments.single.text, 'We saw a camel.');
      expect(back.moments.single.source, 'gallery');
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
