import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  /// [languages] picks the first of these the phone can hear (e.g. `gu_IN`,
  /// `hi_IN`) instead of English; start returns false if it has none.
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
  bool _oneShot = false;
  final _segments = <String>[];
  String _current = '';
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
      final ok = await _stt.initialize(onStatus: _onStatus, onError: _onError);
      if (!ok) {
        final perm = await _stt.hasPermission;
        return _ready = perm ? VoiceReady.unavailable : VoiceReady.noPermission;
      }
      _locales = (await _stt.locales()).map((l) => l.localeId).toList();
      _english = _pickLocale(const ['en_in', 'en_gb', 'en_us']) ?? _pickLocale(const [], anyEnglish: true);
      return _ready = VoiceReady.ready;
    } catch (e) {
      debugPrint('speech init failed: $e');
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

  String get _text => joinSegments([..._segments, _current]);

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
    if (languages != null) {
      _localeId = _pickLocale(languages);
      if (_localeId == null) return false;
    } else {
      _localeId = _english;
    }
    _segments.clear();
    _current = '';
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
    _current = r.recognizedWords;
    if (r.finalResult) {
      _segments.add(_current);
      _current = '';
      if (!(_finished?.isCompleted ?? true)) _finished!.complete();
    }
    _onText?.call(_text);
  }

  void _onStatus(String status) {
    if (status != SpeechToText.doneStatus && status != SpeechToText.notListeningStatus) return;
    if (!(_finished?.isCompleted ?? true) && status == SpeechToText.doneStatus) _finished!.complete();
    if (!_active) return;
    if (_oneShot && _text.isNotEmpty) {
      _endedByItself();
    } else {
      _restartSoon();
    }
  }

  void _onError(SpeechRecognitionError e) {
    debugPrint('speech error: ${e.errorMsg} permanent=${e.permanent}');
    if (!(_finished?.isCompleted ?? true)) _finished!.complete();
    if (_active && e.errorMsg != 'error_permission') _restartSoon();
  }

  void _endedByItself() {
    if (_active) _onEnded?.call();
  }

  void _restartSoon() {
    // "notListening" and "done" both arrive; restart once. Never spin: at
    // most one restart every half second.
    if (_restarting) return;
    _restarting = true;
    final wait = max(150, 500 - DateTime.now().difference(_lastRestart).inMilliseconds);
    Future.delayed(Duration(milliseconds: wait), () async {
      _restarting = false;
      if (!_active || _stt.isListening) return;
      if (_current.isNotEmpty) {
        _segments.add(_current);
        _current = '';
      }
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
    if (_current.isNotEmpty) {
      _segments.add(_current);
      _current = '';
    }
    return _text;
  }

  @override
  Future<void> cancel() async {
    _active = false;
    _cap?.cancel();
    await _stt.cancel();
  }
}
