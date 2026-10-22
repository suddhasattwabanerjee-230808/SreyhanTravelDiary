import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sounds in assets/sounds (made by tool/make_sounds.py).
enum Sfx { pop, listenOn, listenOff, whoosh, shutter, sparkle, dhol, oops }

const _files = {
  Sfx.pop: 'pop',
  Sfx.listenOn: 'listen_on',
  Sfx.listenOff: 'listen_off',
  Sfx.whoosh: 'whoosh',
  Sfx.shutter: 'shutter',
  Sfx.sparkle: 'sparkle',
  Sfx.dhol: 'dhol',
  Sfx.oops: 'oops',
};

/// Sound effects and the garba music loop, each switchable on its own.
/// Effects never take audio focus, so they play over the music instead of
/// stopping it.
class SoundBoard extends ChangeNotifier {
  SoundBoard._(this._prefs, {this.silent = false});

  /// For tests and previews: remembers settings, plays nothing.
  SoundBoard.silent() : this._(null, silent: true);

  static Future<SoundBoard> load() async => SoundBoard._(await SharedPreferences.getInstance());

  final SharedPreferences? _prefs;
  final bool silent;

  static const _musicVolume = 0.35;

  late bool _musicOn = _prefs?.getBool('musicOn') ?? true;
  late bool _sfxOn = _prefs?.getBool('sfxOn') ?? true;
  bool get musicOn => _musicOn;
  bool get sfxOn => _sfxOn;

  AudioPlayer? _music;
  final _sfx = <Sfx, AudioPlayer>{};
  bool _musicWanted = false;
  int _hushes = 0;

  static final _effectContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
    ),
  );

  Future<void> play(Sfx s) async {
    if (silent || !_sfxOn) return;
    try {
      final p = _sfx[s] ??= AudioPlayer()..setAudioContext(_effectContext);
      await p.stop();
      await p.play(AssetSource('sounds/${_files[s]}.wav'), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('sfx $s failed: $e');
    }
  }

  /// Starts (or resumes) the background music if it's switched on.
  Future<void> startMusic() async {
    _musicWanted = true;
    await _syncMusic();
  }

  Future<void> stopMusic() async {
    _musicWanted = false;
    await _syncMusic();
  }

  /// Silences the music while the child is talking; nested calls are fine.
  Future<void> hush() async {
    _hushes++;
    await _syncMusic();
  }

  Future<void> unhush() async {
    if (_hushes > 0) _hushes--;
    await _syncMusic();
  }

  Future<void> _syncMusic() async {
    if (silent) return;
    final shouldPlay = _musicWanted && _musicOn && _hushes == 0;
    try {
      if (shouldPlay) {
        final m = _music ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
        if (m.state == PlayerState.paused) {
          await m.resume();
        } else if (m.state != PlayerState.playing) {
          await m.play(AssetSource('sounds/garba_loop.wav'), volume: _musicVolume);
        }
      } else if (_music?.state == PlayerState.playing) {
        await _music!.pause();
      }
    } catch (e) {
      debugPrint('music failed: $e');
    }
  }

  Future<void> setMusicOn(bool on) async {
    _musicOn = on;
    await _prefs?.setBool('musicOn', on);
    notifyListeners();
    await _syncMusic();
  }

  Future<void> setSfxOn(bool on) async {
    _sfxOn = on;
    await _prefs?.setBool('sfxOn', on);
    notifyListeners();
  }

  @override
  void dispose() {
    _music?.dispose();
    for (final p in _sfx.values) {
      p.dispose();
    }
    super.dispose();
  }
}
