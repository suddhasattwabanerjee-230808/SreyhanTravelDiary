import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'diary_store.dart';
import 'export/share.dart';
import 'models.dart';

/// The whole diary in one .zip, to keep safe or move to a new phone
/// (DiaryFiles.kt does the zipping). Grown-ups' corner only.
class Backup {
  static const _channel = MethodChannel('sreyhan/files');

  /// Zips every day and photo and opens the share sheet (Drive, WhatsApp...).
  static Future<void> share(DiaryStore store, {required String date}) async {
    final out = await Sharer.freshFile('${exportName('diary-backup', date)}.zip');
    await _channel.invokeMethod('zip', {'dir': store.root.path, 'out': out.path});
    await Sharer.shareFile(out, mime: 'application/zip', title: "Sreyhan's diary backup");
  }

  /// Lets the grown-up pick a backup and adds it to this diary. Returns how
  /// many pictures were new, or null if they backed out.
  static Future<int?> restore(DiaryStore store) async {
    final into = Directory('${(await getTemporaryDirectory()).path}/restore');
    final path = await _channel.invokeMethod<String>('openBackup', {'into': into.path});
    if (path == null) return null;
    try {
      return await mergeBackup(store, Directory(path));
    } finally {
      if (await into.exists()) await into.delete(recursive: true);
    }
  }
}

/// Adds the days and photos from an unpacked backup to [store]. Nothing in
/// this diary is lost or replaced: a moment already here (same id) is kept
/// as it is. Returns how many moments were added.
Future<int> mergeBackup(DiaryStore store, Directory backup) async {
  final days = Directory('${backup.path}/days');
  if (!await days.exists()) throw const FormatException("That isn't a diary backup.");
  var added = 0;
  await for (final f in days.list()) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    final incoming = DiaryDay.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    final here = await store.day(incoming.date);
    final have = {for (final m in here.moments) m.id};
    final fresh = [
      for (final m in incoming.moments)
        if (!have.contains(m.id)) m,
    ];
    if (fresh.isEmpty) continue;
    for (final m in fresh) {
      final src = File('${backup.path}/${m.photo}');
      final dst = store.file(m.photo);
      if (await src.exists() && !await dst.exists()) {
        await dst.parent.create(recursive: true);
        await src.copy(dst.path);
      }
    }
    final moments = [...here.moments, ...fresh]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await store.saveDay(here.copyWith(moments: moments));
    added += fresh.length;
  }
  return added;
}
