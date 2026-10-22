// Renders the main screens to PNGs with fake photos, voice and diary days, for
// eyeballing the UI on a machine without an Android device:
//   flutter test test/preview_test.dart --dart-define=PREVIEW_DIR=/some/dir
// Skipped unless PREVIEW_DIR is set.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sreyhan_diary/app_channel.dart';
import 'package:sreyhan_diary/diary_store.dart';
import 'package:sreyhan_diary/games/games_screen.dart';
import 'package:sreyhan_diary/games/ispy_game.dart';
import 'package:sreyhan_diary/games/kite_spell_game.dart';
import 'package:sreyhan_diary/games/sentence_train_game.dart';
import 'package:sreyhan_diary/games/which_photo_game.dart';
import 'package:sreyhan_diary/main.dart';
import 'package:sreyhan_diary/models.dart';
import 'package:sreyhan_diary/place_finder.dart';
import 'package:sreyhan_diary/places.dart';
import 'package:sreyhan_diary/screens/day_screen.dart';
import 'package:sreyhan_diary/screens/export_screen.dart';
import 'package:sreyhan_diary/screens/how_to_screen.dart';
import 'package:sreyhan_diary/screens/moment_screen.dart';
import 'package:sreyhan_diary/screens/parent_corner.dart';
import 'package:sreyhan_diary/screens/passport_screen.dart';
import 'package:sreyhan_diary/screens/word_jar_screen.dart';
import 'package:sreyhan_diary/sound_board.dart';
import 'package:sreyhan_diary/speaker.dart';
import 'package:sreyhan_diary/translate.dart';
import 'package:sreyhan_diary/updates.dart';
import 'package:sreyhan_diary/vision.dart';
import 'package:sreyhan_diary/voice.dart';
import 'package:sreyhan_diary/widgets/mic_button.dart';

const outDir = String.fromEnvironment('PREVIEW_DIR');

/// Says [sentence] every time (the first words live, all of it on stop).
class FakeVoice implements VoiceInput {
  FakeVoice(this.sentence);
  String sentence;
  bool _on = false;

  @override
  Future<VoiceReady> init() async => VoiceReady.ready;
  @override
  bool get listening => _on;
  @override
  Future<bool> start({
    required void Function(String text) onText,
    void Function(double level)? onLevel,
    bool oneShot = false,
    VoidCallback? onEnded,
    List<String>? languages,
  }) async {
    _on = true;
    onText(sentence.split(' ').take(3).join(' '));
    onLevel?.call(0.7);
    return true;
  }

  @override
  Future<String> stop() async {
    _on = false;
    return sentence;
  }

  @override
  Future<void> cancel() async => _on = false;
}

class FakeLabeler implements PhotoLabeler {
  @override
  Future<List<String>> labels(String path) async => const ['Camel', 'Desert', 'Sky'];
}

class FakeTranslator implements WordTranslator {
  @override
  Future<bool> isReady(HomeLanguage lang) async => true;
  @override
  Future<bool> prepare(HomeLanguage lang) async => true;
  @override
  Future<String?> toEnglish(String text, HomeLanguage lang) async => 'hump';
}

class FakePlaces implements PlaceFinder {
  @override
  Future<Place?> find(String path, {required bool camera}) async => placeById('white_rann');
}

class SilentSpeaker implements Speaker {
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> say(String text, {void Function(int start, int end)? onWord}) async {}
  @override
  Future<void> stop() async {}
}

Future<void> _loadFonts() async {
  final baloo = FontLoader('Baloo2');
  for (final w in [500, 600, 700, 800]) {
    baloo.addFont(rootBundle.load('assets/fonts/Baloo2-$w.ttf'));
  }
  await baloo.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('/root/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

/// A fake holiday snap: sky, sand and a simple camel-ish hump.
Future<void> _writePhoto(String path, int seed) async {
  const w = 800, h = 600;
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  final rnd = math.Random(seed);
  final hue = 180 + rnd.nextDouble() * 50;
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  c.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
        HSVColor.fromAHSV(1, hue, 0.4, 0.98).toColor(),
        HSVColor.fromAHSV(1, hue, 0.15, 1).toColor(),
      ]),
  );
  c.drawRect(Rect.fromLTWH(0, h * 0.62, w.toDouble(), h * 0.38), Paint()..color = const Color(0xFFE9C98F));
  c.drawCircle(Offset(w * (0.2 + rnd.nextDouble() * 0.6), h * 0.2), 50, Paint()..color = const Color(0xFFFFE07A));
  final body = Paint()..color = const Color(0xFF9A6A3A);
  final x = w * (0.3 + rnd.nextDouble() * 0.3);
  c.drawOval(Rect.fromCenter(center: Offset(x, h * 0.55), width: 220, height: 120), body);
  c.drawOval(Rect.fromCenter(center: Offset(x - 10, h * 0.45), width: 90, height: 90), body);
  c.drawRect(Rect.fromLTWH(x + 80, h * 0.32, 26, 120), body);
  c.drawOval(Rect.fromCenter(center: Offset(x + 105, h * 0.32), width: 60, height: 34), body);
  for (final dx in [-80.0, -40.0, 40.0, 80.0]) {
    c.drawRect(Rect.fromLTWH(x + dx, h * 0.58, 16, 110), body);
  }
  final img = await r.endRecording().toImage(w, h);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (outDir.isEmpty) {
    test('screen previews (set PREVIEW_DIR to render)', () {}, skip: true);
    return;
  }

  final now = DateTime(2026, 10, 22, 18, 30);
  late Directory tmp;
  late DiaryStore store;
  final photos = <String>[];

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 250));
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('preview-root')));
      final image = await boundary.toImage(pixelRatio: 1.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/$name.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  late FakeVoice voice;

  Future<void> pumpApp(WidgetTester tester, {Widget? screen, String? sentence}) async {
    voice = FakeVoice(sentence ?? 'we saw a big brown camel in the white desert');
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('preview-root'),
        child: DiaryApp(
          store: store,
          sounds: SoundBoard.silent(),
          voice: voice,
          pickPhoto: ({required bool camera}) async => photos.first,
          labeler: FakeLabeler(),
          translator: FakeTranslator(),
          speaker: SilentSpeaker(),
          places: FakePlaces(),
          // The guide has been seen, except in its own previews.
          prefs: Prefs.memory()..setBool(seenGuideKey, true),
          now: () => now,
        ),
      ),
    );
    if (screen != null) {
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      // Pushed with real async running, so the screen's file reads can finish.
      await tester.runAsync(() async {
        nav.push(MaterialPageRoute<void>(builder: (_) => screen));
        await tester.pump(const Duration(milliseconds: 600));
      });
    }
  }

  testWidgets('screens', (tester) async {
    await tester.runAsync(() async {
      await _loadFonts();
      tmp = Directory.systemTemp.createTempSync('diary_preview');
      store = DiaryStore(Directory('${tmp.path}/diary'));
      for (var i = 0; i < 4; i++) {
        final p = '${tmp.path}/photo$i.png';
        await _writePhoto(p, i);
        photos.add(p);
      }
    });

    // An empty diary first.
    await pumpApp(tester);
    await shot(tester, '1_home_empty');

    // Some days filled in.
    await tester.runAsync(() async {
      final texts = [
        'We rode a big brown camel in the white desert.',
        'The flamingos were pink and they stood on one leg!',
        'I ate dhokla and it was soft and yummy.',
      ];
      for (var d = 0; d < 4; d++) {
        for (var m = 0; m < (d == 0 ? 2 : 1 + d % 2); m++) {
          final id = 'd${d}m$m';
          await store.addMoment(
            Moment(
              id: id,
              createdAt: now.subtract(Duration(days: d * (d + 1), hours: m * 3)),
              photo: await store.importPhoto(photos[(d + m) % photos.length], id),
              text: texts[(d + m) % texts.length],
              labels: [
                ['Camel', 'Sky'],
                ['Bird', 'Lake'],
                ['Food', 'Temple'],
                ['Bus', 'Tree'],
              ][(d + m) % 4],
              learned: m == 0 ? [LearnedWord(['hump', 'feather', 'sweet', 'river'][d], 'উট', 'Bengali')] : const [],
              feeling: ['excited', 'happy', null, 'surprised'][(d + m) % 4],
              place: ['white_rann', 'surat', 'gir', 'rani_ki_vav', 'kutch'][(d * 2 + m) % 5],
            ),
          );
        }
      }
    });
    // With a new version waiting.
    Updates.instance.showForTesting(UpdateInfo(versionCode: 200, versionName: '0.4.0', notes: ''));
    await pumpApp(tester);
    await shot(tester, '2_home_days');
    Updates.instance.showForTesting(null);

    await pumpApp(tester, screen: const MomentScreen());
    await shot(tester, '3_moment_pick');

    await pumpApp(tester, screen: MomentScreen(initialPhoto: photos[0]));
    await shot(tester, '4_moment_photo');

    // Tap the mic: listening, with the first words coming in.
    await tester.tap(find.byType(MicButton));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await shot(tester, '5_moment_listening');

    // Tap again: done, all the words as bubbles, and Sheru asks about the camel.
    await tester.tap(find.byType(MicButton));
    await shot(tester, '6_moment_words');

    // Tap a word: it opens for typing.
    await tester.tap(find.text('camel').first);
    await shot(tester, '7_moment_edit_word');
    await tester.enterText(find.byType(TextField), 'camels');
    await tester.tap(find.text('OK'));
    await tester.pump();

    // Say a word in Bengali: its English, ready to add.
    voice.sentence = 'কুঁজ';
    await tester.tap(find.textContaining('বাংলা'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.tap(find.byType(MicButton));
    await shot(tester, '8_moment_bengali');

    // Below the words: faces and the five senses.
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('excited'));
    await shot(tester, '8b_moment_ideas');

    await pumpApp(tester, screen: DayScreen(date: dateKey(now)));
    await shot(tester, '9_day');

    await pumpApp(tester, screen: ExportScreen(date: dateKey(now)));
    await shot(tester, '9b_share_my_day');
    await tester.tap(find.text('Picture postcard'));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '9c_postcard');
    // The app draws its own back buttons, so press the phone's back instead.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Comic strip'));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '9d_comic');

    await pumpApp(tester, screen: const PassportScreen());
    await shot(tester, '9e_passport');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, '9f_passport_stamps');

    await pumpApp(tester, screen: const ParentCorner());
    await shot(tester, '9g_grown_ups');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, '9h_grown_ups_charts');

    // The music button: a song to pick, or none.
    await pumpApp(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).popUntil((r) => r.isFirst);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byIcon(Icons.music_note_rounded));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '9i_music');

    await pumpApp(tester, screen: const WordJarScreen());
    await shot(tester, '10_word_jar');

    await pumpApp(tester, screen: const GamesScreen());
    await shot(tester, '11_games');

    await pumpApp(tester, screen: const WhichPhotoGame(seed: 3));
    await shot(tester, '12_which_photo');

    await pumpApp(tester, screen: const KiteSpellGame(seed: 3));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await shot(tester, '13_kite_spell');

    await pumpApp(tester, screen: const SentenceTrainGame(seed: 3));
    await shot(tester, '14_sentence_train');

    await pumpApp(tester, screen: const ISpyGame());
    await shot(tester, '15_ispy');

    await pumpApp(tester, screen: const HowToScreen());
    await shot(tester, '16_how_to_1');
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await shot(tester, '17_how_to_3');
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, '18_how_to_4');
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, '18b_how_to_say_more');
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await shot(tester, '18c_how_to_passport');

    await tester.runAsync(() async => tmp.deleteSync(recursive: true));
  });
}
