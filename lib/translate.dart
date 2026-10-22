import 'package:flutter/services.dart';

import 'app_channel.dart';

/// The languages a child can say a word in, to get it in English.
enum HomeLanguage {
  bengali('Bengali', 'বাংলা', ['bn_IN', 'bn_BD'], 'bn'),
  hindi('Hindi', 'हिंदी', ['hi_IN'], 'hi');

  const HomeLanguage(this.name, this.native, this.speechLocales, this.code);
  final String name;

  /// The language's own name, in its own script.
  final String native;
  final List<String> speechLocales;

  /// ML Kit's language code.
  final String code;
}

/// Bengali or Hindi to English, on the phone (Google ML Kit, through
/// WordTranslation.kt). Each language needs a one-time download of about
/// 30 MB; after that it works offline.
abstract class WordTranslator {
  Future<bool> isReady(HomeLanguage lang);

  /// Downloads the language if needed; false without internet.
  Future<bool> prepare(HomeLanguage lang);

  /// Null if it can't translate.
  Future<String?> toEnglish(String text, HomeLanguage lang);
}

class DeviceTranslator implements WordTranslator {
  static const _channel = MethodChannel('sreyhan/translate');

  @override
  Future<bool> isReady(HomeLanguage lang) async {
    try {
      return await _channel.invokeMethod<bool>('isReady', {'lang': lang.code}).timeout(const Duration(seconds: 8)) ?? false;
    } catch (e, st) {
      reportError('Translation check: $e', st);
      return false;
    }
  }

  @override
  Future<bool> prepare(HomeLanguage lang) async {
    if (await isReady(lang)) return true;
    try {
      // A slow connection can take a while, but not forever.
      return await _channel.invokeMethod<bool>('download', {'lang': lang.code}).timeout(const Duration(minutes: 4)) ??
          false;
    } catch (e, st) {
      reportError('Translation download: $e', st);
      return false;
    }
  }

  @override
  Future<String?> toEnglish(String text, HomeLanguage lang) async {
    try {
      final raw = await _channel
          .invokeMethod<String>('translate', {'lang': lang.code, 'text': text})
          .timeout(const Duration(seconds: 10));
      final english = cleanTranslation(raw ?? '');
      return english.isEmpty ? null : english;
    } catch (e, st) {
      reportError('Translating: $e', st);
      return null;
    }
  }
}
/// "Camel." → "camel": ready to add mid-sentence as bubbles. Only a leading
/// capital is dropped, so "TV" stays "TV".
String cleanTranslation(String s) {
  final t = s.trim().replaceAll(RegExp(r'[.!?।]+$'), '').trim();
  if (t.length > 1 && RegExp(r'^[A-Z][a-z]').hasMatch(t)) return t[0].toLowerCase() + t.substring(1);
  return t;
}
