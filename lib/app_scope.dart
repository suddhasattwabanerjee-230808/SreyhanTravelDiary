import 'package:flutter/widgets.dart';

import 'app_channel.dart';
import 'diary_store.dart';
import 'place_finder.dart';
import 'sound_board.dart';
import 'speaker.dart';
import 'translate.dart';
import 'vision.dart';
import 'voice.dart';

/// Picks a photo and returns its path, or null if the child backed out.
typedef PhotoPicker = Future<String?> Function({required bool camera});

/// The app's services, handed down the tree. Previews pass fakes.
class App extends InheritedWidget {
  const App({
    super.key,
    required this.store,
    required this.sounds,
    required this.voice,
    required this.pickPhoto,
    required this.labeler,
    required this.translator,
    required this.speaker,
    required this.places,
    required this.prefs,
    this.now = DateTime.now,
    required super.child,
  });

  final DiaryStore store;
  final SoundBoard sounds;
  final VoiceInput voice;
  final PhotoPicker pickPhoto;
  final PhotoLabeler labeler;
  final WordTranslator translator;
  final Speaker speaker;
  final PlaceFinder places;
  final Prefs prefs;
  final DateTime Function() now;

  static App of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<App>()!;

  @override
  bool updateShouldNotify(App old) =>
      store != old.store ||
      sounds != old.sounds ||
      voice != old.voice ||
      pickPhoto != old.pickPhoto ||
      labeler != old.labeler ||
      translator != old.translator ||
      speaker != old.speaker ||
      places != old.places;
}
