import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_channel.dart';
import 'words.dart';

enum VoiceReady { ready, noPermission, unavailable }

/// Speech in, text out. The screens only talk to this, so previews and tests
/// can swap in a fake.
abstract class VoiceInput {
  Future<VoiceReady> init();
  bool get listening;

  /// Starts listening. [onText] gets the whole text so far on every update;
  /// [onLevel] gets loudness from 0 to 1. With [oneShot] listening ends by
  /// itself after the first thing said (for fixing one word). [onEnded] is
  /// called when listening ends by itself, so the screen can wrap up.
  /// [languages] picks the first of these the phone can hear (e.g. `bn_IN`,
  /// `hi_IN`) instead of English. If the phone doesn't list any of them it
  /// tries the first anyway; [languageMissing] then says if that failed.
  Future<bool> start({
    required void Function(String text) onText,
    void Function(double level)? onLevel,
    bool oneShot = false,
    VoidCallback? onEnded,
    List<String>? languages,
  });

  /// Stops and returns everything that was said.
  Future<String> stop();
  Future<void> cancel();

  /// True when the last listen ended because the recogniser can't do the
  /// language asked for.
  bool get languageMissing;
}

/// Android's speech recogniser. The recogniser stops by itself after a pause;
/// until the child taps stop, it's restarted and the words are kept, up to
/// [maxListen] in all.
class DeviceVoiceInput implements VoiceInput {
  static const maxListen = Duration(seconds: 60);

  final _stt = SpeechToText();
  String? _english;
  String? _localeId;
  List<String> _locales = const [];
  VoiceReady? _ready;

  bool _active = false;

  @override
  bool languageMissing = false;

  /// Results count only from start until stop has returned the text; the
  /// recogniser can deliver late ones after that.
  bool _accepting = false;
  bool _oneShot = false;
  final _words = Transcript();
  void Function(String)? _onText;
  void Function(double)? _onLevel;
  VoidCallback? _onEnded;
  Completer<void>? _finished;
  DateTime _lastRestart = DateTime(0);
  bool _restarting = false;
  Timer? _cap;

  @override
  bool get listening => _active;

  @override
  Future<VoiceReady> init() async {
    if (_ready == VoiceReady.ready) return _ready!;
    try {
      // Never wait forever on a plugin: a hang here would freeze the mic.
      final ok = await _stt.initialize(onStatus: _onStatus, onError: _onError).timeout(const Duration(seconds: 10));
      if (!ok) {
        final perm = await _stt.hasPermission;
        return _ready = perm ? VoiceReady.unavailable : VoiceReady.noPermission;
      }
      _locales = (await _stt.locales().timeout(const Duration(seconds: 5))).map((l) => l.localeId).toList();
      _english = _pickLocale(const ['en_in', 'en_gb', 'en_us']) ?? _pickLocale(const [], anyEnglish: true);
      return _ready = VoiceReady.ready;
    } catch (e, st) {
      reportError('Speech recogniser: $e', st);
      return _ready = VoiceReady.unavailable;
    }
  }

  /// The first of [wanted] the phone has (Indian English first for English).
  String? _pickLocale(List<String> wanted, {bool anyEnglish = false}) {
    String norm(String s) => s.replaceAll('-', '_').toLowerCase();
    for (final want in wanted) {
      for (final id in _locales) {
        if (norm(id) == norm(want)) return id;
      }
    }
    if (anyEnglish) {
      for (final id in _locales) {
        if (norm(id).startsWith('en')) return id;
      }
    }
    return null;
  }

  String get _text => _words.text;

  @override
  Future<bool> start({
    required void Function(String text) onText,
    void Function(double level)? onLevel,
    bool oneShot = false,
    VoidCallback? onEnded,
    List<String>? languages,
  }) async {
    if (_active) return true;
    if (await init() != VoiceReady.ready) return false;
    languageMissing = false;
    if (languages != null) {
      // Google's recogniser often lists only some of what it can hear (on
      // Android 16 Bengali was missing), so ask for the language anyway; a
      // "not supported" error then says it really can't.
      _localeId = _pickLocale(languages);
      if (_localeId == null) {
        _localeId = languages.first;
        reportError('Speech: ${languages.first} not in the phone\'s list, trying anyway. Listed: ${_locales.join(', ')}', null);
      }
    } else {
      _localeId = _english;
    }
    _words.clear();
    _accepting = true;
    _onText = onText;
    _onLevel = onLevel;
    _onEnded = onEnded;
    _oneShot = oneShot;
    _active = true;
    _cap = Timer(maxListen, _endedByItself);
    await _listen();
    // Stopped while the recogniser was still starting up.
    if (!_active) await _stt.cancel();
    return true;
  }

  Future<void> _listen() async {
    _finished = Completer<void>();
    _lastRestart = DateTime.now();
    await _stt.listen(
      onResult: _onResult,
      onSoundLevelChange: (level) => _onLevel?.call(((level + 2) / 12).clamp(0.0, 1.0)),
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        listenMode: _oneShot ? ListenMode.confirmation : ListenMode.dictation,
        cancelOnError: false,
        listenFor: maxListen,
        pauseFor: Duration(seconds: _oneShot ? 3 : 5),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!_accepting) return;
    if (_words.add(r.recognizedWords, isFinal: r.finalResult)) _completeFinished();
    _onText?.call(_text);
  }

  void _completeFinished() {
    if (!(_finished?.isCompleted ?? true)) _finished!.complete();
  }

  void _onStatus(String status) {
    // "done" comes after the final words (or after waiting for them), so
    // restarting then never races a late final result.
    if (status != SpeechToText.doneStatus) return;
    _completeFinished();
    if (!_active) return;
    if (_oneShot && _text.isNotEmpty) {
      _endedByItself();
    } else {
      _restartSoon();
    }
  }

  static const _languageErrors = {'error_language_not_supported', 'error_language_unavailable'};

  void _onError(SpeechRecognitionError e) {
    debugPrint('speech error: ${e.errorMsg} permanent=${e.permanent}');
    _completeFinished();
    if (!_active) return;
    if (_languageErrors.contains(e.errorMsg)) {
      // Restarting can't help: end, and let the screen say why.
      languageMissing = true;
      reportError('Speech: $_localeId: ${e.errorMsg}', null);
      _endedByItself();
      return;
    }
    if (e.errorMsg != 'error_permission') _restartSoon();
  }

  void _endedByItself() {
    if (_active) _onEnded?.call();
  }

  void _restartSoon() {
    // A "done" and an error can both arrive; restart once. Never spin: at
    // most one restart every half second.
    if (_restarting) return;
    _restarting = true;
    final wait = max(150, 500 - DateTime.now().difference(_lastRestart).inMilliseconds);
    Future.delayed(Duration(milliseconds: wait), () async {
      _restarting = false;
      if (!_active || _stt.isListening) return;
      _words.keepCurrent();
      try {
        await _listen();
      } catch (e) {
        debugPrint('speech restart failed: $e');
      }
    });
  }

  @override
  Future<String> stop() async {
    // Tapped stop before listening really started: nothing was said.
    if (!_active) return '';
    _active = false;
    _cap?.cancel();
    await _stt.stop();
    // The final words arrive a moment after stopping.
    await (_finished?.future ?? Future.value()).timeout(const Duration(milliseconds: 1500), onTimeout: () {});
    _words.keepCurrent();
    _accepting = false;
    _onText = null;
    return _text;
  }

  @override
  Future<void> cancel() async {
    _active = false;
    _accepting = false;
    _onText = null;
    _cap?.cancel();
    await _stt.cancel();
  }
}

/// The words heard in one go at the mic, across the recogniser's pauses and
/// restarts. Android's recogniser can send the same words again after a
/// pause (a late final, or a repeat), and this must never add them twice.
class Transcript {
  final _segments = <String>[];
  String _current = '';

  /// A segment kept from partial words when listening paused; its final
  /// version may still arrive (and replaces it) or be repeated (ignored).
  int? _provisional;

  String get text => joinSegments([..._segments, _current]);

  void clear() {
    _segments.clear();
    _current = '';
    _provisional = null;
  }

  /// Takes one result from the recogniser; true when it was a final one.
  bool add(String recognised, {required bool isFinal}) {
    final words = recognised.trim();
    final p = _provisional;
    if (p != null && _current.isEmpty && _related(words, _segments[p])) {
      // The paused session's words arriving late: refresh them, never add.
      if (isFinal) {
        if (words.isNotEmpty) _segments[p] = words;
        _provisional = null;
      }
      return isFinal;
    }
    // New speech always arrives as partial words first, so a final with none
    // before it that matches the last segment is the recogniser repeating itself.
    if (isFinal && _current.isEmpty && _segments.isNotEmpty && words.toLowerCase() == _segments.last.toLowerCase()) {
      return true;
    }
    if (words.isNotEmpty) _provisional = null;
    if (isFinal) {
      if (words.isNotEmpty) _segments.add(words);
      _current = '';
    } else {
      _current = words;
    }
    return isFinal;
  }

  /// Keeps words heard so far that never got a final version (listening
  /// paused or stopped).
  void keepCurrent() {
    if (_current.isEmpty) return;
    _segments.add(_current);
    _provisional = _segments.length - 1;
    _current = '';
  }

  /// One is the start of the other: the same speech, more or less of it.
  static bool _related(String a, String b) {
    final x = a.toLowerCase(), y = b.toLowerCase();
    return x.isNotEmpty && (x.startsWith(y) || y.startsWith(x));
  }
}
