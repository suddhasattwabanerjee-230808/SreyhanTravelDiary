# Sreyhan's Travel Diary

A playful travel diary for an 8-year-old that helps them talk about their
photos in English. Take or pick a photo, tap the big floating mic and talk,
and the words are written down as bubbles (speech to text). Tap a bubble to
say it again or pop it. Sheru the Gir lion cub looks at the photo and asks
questions to help, turns the child's words into a Super Sentence with new words
to learn, and gives stars for reading it back aloud. New words collect in the
Word Jar.
There's no keyboard anywhere. Each day becomes a kite in the Uttarayan sky
over the white Rann.

Android only, Flutter. The diary stays on the phone (`diary/` in the app's
documents folder: one JSON file per day plus the photos). Sheru's coaching
goes through a small Cloudflare Worker to the Claude API (`coach-worker/`, see
its README); without it, the app works offline with built-in questions.

- `flutter analyze && flutter test`: checks and unit tests.
- `flutter test test/preview_test.dart --dart-define=PREVIEW_DIR=/some/dir`
  renders the main screens to PNGs with fake photos and speech.
- `python3 tool/make_sounds.py` regenerates the sound effects and garba
  music loop in `assets/sounds/` (needs numpy). All sounds are synthesised
  here, so no licences apply.
- `node coach-worker/test.mjs` tests the coach Worker.
- APKs build in CI (`.github/workflows/flutter-ci.yml`). Each build on `main`
  replaces the `latest` release, so the newest APK is always at
  `releases/latest/download/SreyhanDiary.apk`. Every build is signed with the
  same key (`android/app/sreyhan-debug.keystore`), so updates install over the
  old app and keep the diary.

Font: Baloo 2 (SIL OFL 1.1, `assets/fonts/OFL.txt`), subset to Latin.
