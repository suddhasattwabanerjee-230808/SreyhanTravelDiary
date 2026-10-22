import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Hands a made file to Android's share sheet (ShareFile.kt).
class Sharer {
  static const _channel = MethodChannel('sreyhan/share');
  static const _files = MethodChannel('sreyhan/files');

  /// A new file called [name] in an emptied share folder: only the latest
  /// export is kept, old ones are never needed again.
  static Future<File> freshFile(String name) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    return File('${dir.path}/$name');
  }

  /// Writes [bytes] to the share folder as [name] and opens the share sheet.
  static Future<void> shareBytes(Uint8List bytes, String name, {required String mime, required String title}) async {
    final file = await freshFile(name);
    await file.writeAsBytes(bytes, flush: true);
    await shareFile(file, mime: mime, title: title);
  }

  static Future<void> shareFile(File file, {required String mime, required String title}) =>
      _channel.invokeMethod('share', {'path': file.path, 'mime': mime, 'title': title});

  /// Puts a PNG in the phone's gallery (Pictures/Sreyhan Diary).
  static Future<void> saveToGallery(Uint8List png, String name) async {
    final file = await freshFile(name);
    await file.writeAsBytes(png, flush: true);
    await _files.invokeMethod('saveToGallery', {'path': file.path, 'name': name});
  }
}

/// "Sreyhan-diary-2026-10-22": a file name without spaces or apostrophes.
String exportName(String what, String date) => 'Sreyhan-$what-$date';
