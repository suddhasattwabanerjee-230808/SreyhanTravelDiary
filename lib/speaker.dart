import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'app_channel.dart';

/// Reads text aloud, telling the screen which word is being spoken so it can
/// light up karaoke-style.
abstract class Speaker {
  /// Completes when speaking finishes or is stopped. [onWord] gets the
  /// character range of the word being spoken.
  Future<void> say(String text, {void Function(int start, int end)? onWord});
  Future<void> stop();
}

class DeviceSpeaker implements Speaker {
  final _tts = FlutterTts();
  Future<void>? _setup;
  Completer<void>? _done;
  void Function(int, int)? _onWord;

  Future<void> _init() async {
    // Indian English if the phone has it; slow and a little bright for a child.
    final hasIndian = await _tts.isLanguageAvailable('en-IN') == true;
    await _tts.setLanguage(hasIndian ? 'en-IN' : 'en-GB');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.08);
    _tts.setProgressHandler((text, start, end, word) => _onWord?.call(start, end));
    void finish() {
      if (!(_done?.isCompleted ?? true)) _done!.complete();
    }

    _tts.setCompletionHandler(finish);
    _tts.setCancelHandler(finish);
    _tts.setErrorHandler((_) => finish());
  }

  @override
  Future<void> say(String text, {void Function(int start, int end)? onWord}) async {
    try {
      try {
        await (_setup ??= _init().timeout(const Duration(seconds: 5)));
      } catch (_) {
        // Try setting up again next time instead of staying silent for good.
        _setup = null;
        rethrow;
      }
      await stop();
      _onWord = onWord;
      _done = Completer<void>();
      await _tts.speak(text);
      // Never hang a screen on a speech engine that forgets to call back.
      await _done!.future.timeout(Duration(seconds: 4 + text.length ~/ 8), onTimeout: () {});
    } catch (e, st) {
      reportError('Speaking: $e', st);
    } finally {
      _onWord = null;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (!(_done?.isCompleted ?? true)) _done!.complete();
  }
}
