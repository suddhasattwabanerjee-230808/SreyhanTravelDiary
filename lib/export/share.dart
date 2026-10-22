import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Hands a made file to Android's share sheet (ShareFile.kt).
class Sharer {
  static const _channel = MethodChannel('sreyhan/share');

  /// Writes [bytes] to the share folder as [name] and opens the share sheet.
  static Future<void> shareBytes(Uint8List bytes, String name, {required String mime, required String title}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    // Only today's file is kept: old exports are never needed again.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await _channel.invokeMethod('share', {'path': file.path, 'mime': mime, 'title': title});
  }
}

/// "Sreyhan-diary-2026-10-22": a file name without spaces or apostrophes.
String exportName(String what, String date) => 'Sreyhan-$what-$date';
