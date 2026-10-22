import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'app_channel.dart';

/// The languages a child can say a word in, to get it in English.
enum HomeLanguage {
  bengali('Bengali', 'বাংলা', ['bn_IN', 'bn_BD'], TranslateLanguage.bengali),
  hindi('Hindi', 'हिंदी', ['hi_IN'], TranslateLanguage.hindi);

  const HomeLanguage(this.name, this.native, this.speechLocales, this.mlkit);
  final String name;

  /// The language's own name, in its own script.
  final String native;
  final List<String> speechLocales;
  final TranslateLanguage mlkit;
}

/// Bengali or Hindi to English, on the phone (Google ML Kit). Each language
/// needs a one-time download of about 30 MB; after that it works offline.
abstract class WordTranslator {
  Future<bool> isReady(HomeLanguage lang);

  /// Downloads the language if needed; false without internet.
  Future<bool> prepare(HomeLanguage lang);

  /// Null if it can't translate.
  Future<String?> toEnglish(String text, HomeLanguage lang);
}

class DeviceTranslator implements WordTranslator {
  final _models = OnDeviceTranslatorModelManager();
  final _translators = <HomeLanguage, OnDeviceTranslator>{};

  @override
  Future<bool> isReady(HomeLanguage lang) async {
    try {
      const wait = Duration(seconds: 5);
      return await _models.isModelDownloaded(lang.mlkit.bcpCode).timeout(wait) &&
          await _models.isModelDownloaded(TranslateLanguage.english.bcpCode).timeout(wait);
    } catch (e) {
      debugPrint('translation check failed: $e');
      return false;
    }
  }

  @override
  Future<bool> prepare(HomeLanguage lang) async {
    if (await isReady(lang)) return true;
    try {
      // A slow connection can take a while, but not forever.
      const wait = Duration(minutes: 3);
      return await _models.downloadModel(lang.mlkit.bcpCode, isWifiRequired: false).timeout(wait) &&
          await _models.downloadModel(TranslateLanguage.english.bcpCode, isWifiRequired: false).timeout(wait);
    } catch (e, st) {
      reportError('Translation download: $e', st);
      return false;
    }
  }

  @override
  Future<String?> toEnglish(String text, HomeLanguage lang) async {
    try {
      final t = _translators[lang] ??= OnDeviceTranslator(
        sourceLanguage: lang.mlkit,
        targetLanguage: TranslateLanguage.english,
      );
      final english = cleanTranslation(await t.translateText(text).timeout(const Duration(seconds: 10)));
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
