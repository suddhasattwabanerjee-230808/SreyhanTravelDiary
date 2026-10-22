import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sreyhan_diary/backup.dart';
import 'package:sreyhan_diary/diary_store.dart';
import 'package:sreyhan_diary/feelings.dart';
import 'package:sreyhan_diary/models.dart';
import 'package:sreyhan_diary/places.dart';
import 'package:sreyhan_diary/stats.dart';

Moment moment(String id, String text, {DateTime? at, String? place, List<String> learned = const []}) => Moment(
  id: id,
  createdAt: at ?? DateTime(2026, 10, 22, 10),
  photo: 'media/$id.jpg',
  text: text,
  place: place,
  learned: [for (final w in learned) LearnedWord(w, 'x', 'Hindi')],
);

void main() {
  group('places', () {
    test('every district and sight is inside the Gujarat outline', () {
      for (final p in [...districts, ...landmarks]) {
        expect(inGujarat(p.lat, p.lng), isTrue, reason: p.name);
      }
    });

    test('cities elsewhere are outside it', () {
      for (final id in ['kolkata', 'mumbai', 'delhi', 'jaipur', 'goa']) {
        final c = placeById(id)!;
        expect(inGujarat(c.lat, c.lng), isFalse, reason: c.name);
      }
    });

    test('ids are unique, and sights name a real district', () {
      final all = [...districts, ...landmarks, ...cities];
      expect(all.map((p) => p.id).toSet().length, all.length);
      for (final l in landmarks) {
        expect(placeById(l.district)?.kind, PlaceKind.district, reason: l.name);
      }
    });

    test('a photo near a sight gets the sight', () {
      expect(placeAt(21.839, 73.717)?.id, 'statue_of_unity');
      expect(placeAt(23.86, 72.10)?.id, 'rani_ki_vav');
    });

    test('elsewhere in Gujarat gets the nearest district', () {
      // Bhuj market, away from the sights.
      expect(placeAt(23.26, 69.68)?.id, 'kutch');
      // Between Rajkot and Morbi, nearer Rajkot.
      expect(placeAt(22.42, 70.80)?.id, 'rajkot');
    });

    test('outside Gujarat: a nearby city, or nowhere', () {
      expect(placeAt(22.58, 88.35)?.id, 'kolkata');
      expect(placeAt(24.59, 72.71)?.id, 'mount_abu');
      expect(placeAt(51.5, -0.12), isNull);
    });

    test('stamps include the districts of the sights', () {
      expect(passportStamps(['gir', 'surat', 'kolkata']), {'gir', 'junagadh', 'surat', 'kolkata'});
    });

    test('distances are about right', () {
      // Ahmedabad to Surat is about 210 km as the crow flies.
      final a = placeById('ahmedabad')!, s = placeById('surat')!;
      expect(distanceKm(a.lat, a.lng, s.lat, s.lng), closeTo(210, 10));
    });
  });

  group('feelings', () {
    test('found by name, and ask why', () {
      expect(Feeling.byName('excited'), Feeling.excited);
      expect(Feeling.byName(null), isNull);
      expect(Feeling.byName('grumpy'), isNull);
      expect(Feeling.happy.why, contains('because'));
    });

    test('a moment keeps its feeling and place, and old moments still load', () {
      final m = Moment(
        id: 'a',
        createdAt: DateTime(2026, 10, 22),
        photo: 'media/a.jpg',
        text: 'Hi.',
        feeling: 'happy',
        place: 'gir',
      );
      final back = Moment.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(back.feeling, 'happy');
      expect(back.place, 'gir');
      final old = Moment.fromJson({'id': 'b', 'createdAt': '2026-10-22T10:00:00.000', 'photo': 'media/b.jpg', 'text': 'Hi.'});
      expect(old.feeling, isNull);
      expect(old.place, isNull);
    });
  });

  group('stats', () {
    test('words, describing words and new words per day, oldest first', () {
      final days = [
        DiaryDay(
          date: '2026-10-23',
          moments: [moment('c', 'The sea was blue.', learned: ['wave', 'hump'])],
        ),
        DiaryDay(
          date: '2026-10-22',
          moments: [
            moment('a', 'We saw a big brown camel!', learned: ['hump']),
            moment('b', 'It was hot.'),
          ],
        ),
      ];
      final s = dayStats(days);
      expect(s.map((d) => d.date), ['2026-10-22', '2026-10-23']);
      expect(s[0].pictures, 2);
      expect(s[0].words, 9);
      expect(s[0].sentenceLength, 4.5);
      expect(s[0].describing, 3); // big, brown, hot
      expect(s[0].newWords, 1);
      expect(s[1].describing, 1); // blue
      expect(s[1].newWords, 1); // "hump" was already known
    });
  });

  group('backup', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('diary_backup'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('merging adds new moments and photos, keeps what is here', () async {
      final here = DiaryStore(Directory('${tmp.path}/here'));
      await here.saveDay(DiaryDay(date: '2026-10-22', moments: [moment('a', 'Mine.')]));

      // An unpacked backup from another phone: the same moment, a new one
      // the same day, and a whole new day.
      final backup = Directory('${tmp.path}/backup');
      final other = DiaryStore(backup);
      await other.saveDay(
        DiaryDay(
          date: '2026-10-22',
          moments: [moment('a', 'Theirs.'), moment('b', 'New.', at: DateTime(2026, 10, 22, 9))],
        ),
      );
      await other.saveDay(DiaryDay(date: '2026-10-21', moments: [moment('c', 'Older.', at: DateTime(2026, 10, 21))]));
      File('${backup.path}/media/b.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);

      expect(await mergeBackup(here, backup), 2);
      final day = await here.day('2026-10-22');
      expect(day.moments.map((m) => m.id), ['b', 'a']);
      expect(day.moments.last.text, 'Mine.');
      expect(here.file('media/b.jpg').readAsBytesSync(), [1, 2, 3]);
      expect((await here.allDays()).length, 2);
      // A second time adds nothing.
      expect(await mergeBackup(here, backup), 0);
    });

    test('a folder without days is not a backup', () async {
      final here = DiaryStore(Directory('${tmp.path}/here'));
      expect(() => mergeBackup(here, tmp), throwsFormatException);
    });

    test('deleting a day removes it and its photos', () async {
      final store = DiaryStore(Directory('${tmp.path}/d'));
      final photo = File('${tmp.path}/p.jpg')..writeAsBytesSync([9]);
      final rel = await store.importPhoto(photo.path, 'x');
      await store.addMoment(Moment(id: 'x', createdAt: DateTime(2026, 10, 22), photo: rel, text: 'Bye.'));
      await store.deleteDay('2026-10-22');
      expect(store.file(rel).existsSync(), isFalse);
      expect(await store.allDays(), isEmpty);
    });
  });
}
