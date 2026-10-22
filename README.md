# Sreyhan's Travel Diary

A playful travel diary for an 8-year-old that helps them talk about their
photos in English. Take or pick a photo, tap the big floating mic and talk,
and the words are written down as bubbles (speech to text). Tap a bubble to
fix its spelling with the keyboard. Sheru the Gir lion cub asks questions
about what's in the photo, and a word the child only knows in Bengali or Hindi
can be said in that language and comes back in English. Those words collect in
the Word Jar. Four games are built from the diary itself: Which Photo?, Kite
Spell, Sentence Train and Travel I-Spy. Each day becomes a kite in the
Uttarayan sky over the white Rann.

Android only, Flutter, and free to run: everything happens on the phone. The
diary is stored in `diary/` in the app's documents folder (one JSON file per
day plus the photos). Photo labels and Bengali/Hindi translation use Google
ML Kit on the device; translation downloads each language once (~30 MB), then
works offline.

- `flutter analyze && flutter test`: checks and unit tests.
- `flutter test test/preview_test.dart --dart-define=PREVIEW_DIR=/some/dir`
  renders the main screens to PNGs with fake photos and speech.
- `python3 tool/make_sounds.py` regenerates the sound effects and garba
  music loop in `assets/sounds/` (needs numpy). All sounds are synthesised
  here, so no licences apply.
- APKs build in CI (`.github/workflows/flutter-ci.yml`). Each build on `main`
  replaces the `latest` release, so the newest APK is always at
  `releases/latest/download/SreyhanDiary.apk`. Every build is signed with the
  same key (`android/app/sreyhan-debug.keystore`), so updates install over the
  old app and keep the diary.

Font: Baloo 2 (SIL OFL 1.1, `assets/fonts/OFL.txt`), subset to Latin.
