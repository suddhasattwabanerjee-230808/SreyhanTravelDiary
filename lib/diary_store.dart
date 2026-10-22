import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// The diary on disk, offline only:
///   `diary/days/<yyyy-mm-dd>.json`   one file per day
///   `diary/media/<id>.jpg`          photos
/// Listeners are told whenever a day changes.
class DiaryStore extends ChangeNotifier {
  DiaryStore(this.root);

  final Directory root;

  static Future<DiaryStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    return DiaryStore(Directory('${docs.path}/diary'));
  }

  Directory get _days => Directory('${root.path}/days');
  Directory get _media => Directory('${root.path}/media');

  File file(String relative) => File('${root.path}/$relative');

  static String newId() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 20).toRadixString(36)}';
  }

  /// Every day that has at least one moment, newest first.
  Future<List<DiaryDay>> allDays() async {
    if (!await _days.exists()) return [];
    final days = <DiaryDay>[];
    await for (final f in _days.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final d = DiaryDay.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        if (!d.isEmpty) days.add(d);
      } catch (e) {
        debugPrint('Skipping unreadable day ${f.path}: $e');
      }
    }
    days.sort((a, b) => b.date.compareTo(a.date));
    return days;
  }

  Future<DiaryDay> day(String date) async {
    final f = File('${_days.path}/$date.json');
    if (!await f.exists()) return DiaryDay(date: date);
    return DiaryDay.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  Future<void> saveDay(DiaryDay day) async {
    await _days.create(recursive: true);
    final f = File('${_days.path}/${day.date}.json');
    // Write then rename, so a crash mid-write never loses the day.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert(day.toJson()), flush: true);
    await tmp.rename(f.path);
    notifyListeners();
  }

  /// Copies a picked photo into the diary and returns its relative path.
  Future<String> importPhoto(String sourcePath, String id) async {
    await _media.create(recursive: true);
    final ext = sourcePath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final rel = 'media/$id.$ext';
    await File(sourcePath).copy(file(rel).path);
    return rel;
  }

  Future<void> addMoment(Moment m) async {
    final d = await day(dateKey(m.createdAt));
    await saveDay(d.copyWith(moments: [...d.moments, m]));
  }

  Future<void> deleteMoment(String date, String id) async {
    final d = await day(date);
    final gone = d.moments.where((m) => m.id == id).toList();
    await saveDay(d.copyWith(moments: d.moments.where((m) => m.id != id).toList()));
    for (final m in gone) {
      final f = file(m.photo);
      if (await f.exists()) await f.delete();
    }
  }
}
