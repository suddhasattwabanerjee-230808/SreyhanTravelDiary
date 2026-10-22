import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sreyhan_diary/diary_store.dart';
import 'package:sreyhan_diary/export/storybook.dart';
import 'package:sreyhan_diary/models.dart';

/// A small real PNG to stand in for a photo.
Future<List<int>> _png() async {
  final r = ui.PictureRecorder();
  Canvas(r).drawRect(const Rect.fromLTWH(0, 0, 40, 30), Paint()..color = const Color(0xFF6ECBFF));
  final img = await r.endRecording().toImage(40, 30);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  testWidgets('a storybook is a PDF with a cover and a page per moment', (tester) async {
    await tester.runAsync(() async {
      final tmp = Directory.systemTemp.createTempSync('storybook_test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final store = DiaryStore(Directory('${tmp.path}/diary'));
      final photo = File('${tmp.path}/p.png')..writeAsBytesSync(await _png());
      for (final (i, d) in [DateTime(2026, 10, 21, 9), DateTime(2026, 10, 22, 9), DateTime(2026, 10, 22, 15)].indexed) {
        await store.addMoment(
          Moment(
            id: 'm$i',
            createdAt: d,
            photo: await store.importPhoto(photo.path, 'm$i'),
            text: 'We rode a camel in the desert.',
            learned: i == 0 ? const [LearnedWord('camel', 'উট', 'Bengali')] : const [],
          ),
        );
      }
      final days = (await store.allDays()).reversed.toList();

      final pdf = await buildStorybook(store, days, childName: 'Sreyhan');

      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      // Cover + 3 moments.
      expect(RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(pdf)).length, 4);
    });
  });
}
