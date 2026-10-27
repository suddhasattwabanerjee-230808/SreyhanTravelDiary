import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'app_channel.dart';
import 'app_scope.dart';
import 'cloud_sync.dart';
import 'diary_store.dart';
import 'place_finder.dart';
import 'screens/home_screen.dart';
import 'sound_board.dart';
import 'speaker.dart';
import 'translate.dart';
import 'updates.dart';
import 'theme.dart';
import 'vision.dart';
import 'voice.dart';

/// Whatever goes wrong while starting, the diary still opens: each step has
/// a time limit, and errors are noted in Download (SreyhanDiary-crash-…)
/// rather than leaving a black screen.
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      reportError(details.exception, details.stack);
    };
    Future<T> step<T>(String name, Future<T> Function() run, T Function() fallback) async {
      try {
        return await run().timeout(const Duration(seconds: 5));
      } catch (e, st) {
        reportError('Starting up ($name): $e', st);
        return fallback();
      }
    }

    // All at once rather than one after another: a quicker start.
    final orientation = step(
      'orientation',
      () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
      () {},
    );
    final opening = step(
      'diary folder',
      DiaryStore.open,
      // Where path_provider puts app documents on Android anyway.
      () => DiaryStore(Directory('/data/user/0/com.bittu.sreyhan_diary/app_flutter/diary')),
    );
    final loading = Prefs.load();
    final cloud = _initFirebase();
    await orientation;
    final store = await opening;
    final prefs = await loading;
    await cloud;
    await CloudDiarySync.instance.attach(store, places: DevicePlaceFinder());
    runApp(
      DiaryApp(
        store: store,
        sounds: SoundBoard(prefs),
        prefs: prefs,
        voice: DeviceVoiceInput(),
        pickPhoto: pickPhotoFromDevice,
        labeler: DeviceLabeler(),
        translator: DeviceTranslator(),
        speaker: DeviceSpeaker(),
        places: DevicePlaceFinder(),
        onResumed: Updates.instance.checkIfDue,
      ),
    );
    Updates.instance.checkIfDue();
  }, reportError);
}

/// Photos are scaled down on the way in: plenty for a page or a print, light
/// on storage, and quick to save and show.
Future<String?> pickPhotoFromDevice({required bool camera}) async {
  final x = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 82,
  );
  return x?.path;
}

/// Cloud sync is optional until the Android app is registered in Firebase.
/// The offline diary still opens normally when the config file is absent.
Future<void> _initFirebase() async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp().timeout(const Duration(seconds: 5));
  } catch (e, st) {
    reportError('Firebase setup: $e', st);
  }
}

class DiaryApp extends StatefulWidget {
  const DiaryApp({
    super.key,
    required this.store,
    required this.sounds,
    required this.voice,
    required this.pickPhoto,
    required this.labeler,
    required this.translator,
    required this.speaker,
    this.places,
    this.prefs,
    this.now = DateTime.now,
    this.onResumed,
  });

  final DiaryStore store;
  final SoundBoard sounds;
  final VoiceInput voice;
  final PhotoPicker pickPhoto;
  final PhotoLabeler labeler;
  final WordTranslator translator;
  final Speaker speaker;

  /// Where photos were taken; previews and tests know nowhere.
  final PlaceFinder? places;

  /// Saved settings; previews get ones that save nowhere.
  final Prefs? prefs;
  final DateTime Function() now;

  /// When the app comes back to the front (checks for updates).
  final VoidCallback? onResumed;

  @override
  State<DiaryApp> createState() => _DiaryAppState();
}

class _DiaryAppState extends State<DiaryApp> with WidgetsBindingObserver {
  final _memoryPrefs = Prefs.memory();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sounds.startMusic();
    // Once the home screen is up, get Sheru's voice ready in the background.
    Future.delayed(const Duration(seconds: 2), widget.speaker.warmUp);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Music only while the diary is on screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.sounds.startMusic();
      widget.onResumed?.call();
      unawaited(CloudDiarySync.instance.syncNow());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      widget.sounds.stopMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return App(
      store: widget.store,
      sounds: widget.sounds,
      voice: widget.voice,
      pickPhoto: widget.pickPhoto,
      labeler: widget.labeler,
      translator: widget.translator,
      speaker: widget.speaker,
      places: widget.places ?? const NoPlaces(),
      prefs: widget.prefs ?? _memoryPrefs,
      now: widget.now,
      child: MaterialApp(
        title: "Sreyhan's Travel Diary",
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
