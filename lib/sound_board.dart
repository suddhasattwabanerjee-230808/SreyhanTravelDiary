import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_channel.dart';

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

/// The music to choose from: our own loops (tool/make_sounds.py), or a song
/// a grown-up picked from the phone.
enum MusicTrack {
  garba('Garba', 'garba_loop'),
  blocks('Block World', 'blocks_loop'),
  obby('Obby Dash', 'obby_loop'),
  own('My own song', null);

  const MusicTrack(this.label, this.file);
  final String label;
  final String? file;
}

/// Sound effects and a music loop, each switchable on its own.
/// Effects never take audio focus, so they play over the music instead of
/// stopping it.
class SoundBoard extends ChangeNotifier {
  SoundBoard(this._prefs, {this.silent = false});

  /// For tests and previews: remembers settings, plays nothing.
  SoundBoard.silent() : this(Prefs.memory(), silent: true);

  final Prefs _prefs;
  final bool silent;

  static const _musicVolume = 0.35;

  late bool _musicOn = _prefs.getBool('musicOn') ?? true;
  late bool _sfxOn = _prefs.getBool('sfxOn') ?? true;
  late MusicTrack _track = MusicTrack.values.where((m) => m.name == _prefs.getString('music')).firstOrNull ?? MusicTrack.garba;
  bool get musicOn => _musicOn;
  bool get sfxOn => _sfxOn;
  MusicTrack get track => _track;

  /// The grown-up's own song, copied into the app, and what it was called.
  String? get ownSong => _prefs.getString('ownSong');
  String? get ownSongName => _prefs.getString('ownSongName');

  /// The tracks that can be picked: "My own song" only once there is one.
  List<MusicTrack> get tracks => [for (final m in MusicTrack.values) if (m != MusicTrack.own || ownSong != null) m];

  /// What the music player is set up to play, so a new choice restarts it.
  String? _loaded;

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
      await p.play(AssetSource('sounds/${_files[s]}.ogg'), mode: PlayerMode.lowLatency);
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
        final own = ownSong;
        final useOwn = _track == MusicTrack.own && own != null && File(own).existsSync();
        final want = useOwn ? own : 'sounds/${(_track.file ?? MusicTrack.garba.file)!}.ogg';
        if (_loaded != want) {
          _loaded = want;
          await m.stop();
          await m.play(useOwn ? DeviceFileSource(want) : AssetSource(want), volume: _musicVolume);
        } else if (m.state == PlayerState.paused) {
          await m.resume();
        } else if (m.state != PlayerState.playing) {
          await m.play(useOwn ? DeviceFileSource(want) : AssetSource(want), volume: _musicVolume);
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
    await _prefs.setBool('musicOn', on);
    notifyListeners();
    await _syncMusic();
  }

  /// Plays [track] from now on (and switches the music on).
  Future<void> setTrack(MusicTrack track) async {
    _track = track;
    _musicOn = true;
    await _prefs.setString('music', track.name);
    await _prefs.setBool('musicOn', true);
    notifyListeners();
    await _syncMusic();
  }

  /// Remembers a song a grown-up picked (already copied into the app) and
  /// plays it.
  Future<void> setOwnSong(String path, String name) async {
    await _prefs.setString('ownSong', path);
    await _prefs.setString('ownSongName', name);
    _loaded = null;
    await setTrack(MusicTrack.own);
  }

  Future<void> setSfxOn(bool on) async {
    _sfxOn = on;
    await _prefs.setBool('sfxOn', on);
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
