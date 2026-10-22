import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'app_scope.dart';
import 'coach.dart';
import 'diary_store.dart';
import 'env.dart';
import 'screens/home_screen.dart';
import 'sound_board.dart';
import 'speaker.dart';
import 'theme.dart';
import 'voice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await DiaryStore.open();
  final sounds = await SoundBoard.load();
  runApp(
    DiaryApp(
      store: store,
      sounds: sounds,
      voice: DeviceVoiceInput(),
      pickPhoto: pickPhotoFromDevice,
      coach: HttpCoach(coachUrl, coachToken),
      speaker: DeviceSpeaker(),
    ),
  );
}

/// Photos are scaled down on the way in: plenty for a page, light on storage.
Future<String?> pickPhotoFromDevice({required bool camera}) async {
  final x = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 85,
  );
  return x?.path;
}

class DiaryApp extends StatefulWidget {
  const DiaryApp({
    super.key,
    required this.store,
    required this.sounds,
    required this.voice,
    required this.pickPhoto,
    required this.coach,
    required this.speaker,
    this.now = DateTime.now,
  });

  final DiaryStore store;
  final SoundBoard sounds;
  final VoiceInput voice;
  final PhotoPicker pickPhoto;
  final Coach coach;
  final Speaker speaker;
  final DateTime Function() now;

  @override
  State<DiaryApp> createState() => _DiaryAppState();
}

class _DiaryAppState extends State<DiaryApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sounds.startMusic();
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
      coach: widget.coach,
      speaker: widget.speaker,
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
