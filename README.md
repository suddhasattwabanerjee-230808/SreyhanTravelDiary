# Sreyhan's Travel Diary

A playful travel diary for an 8-year-old that helps them talk about their
photos in English. Take or pick a photo, tap the big floating mic and talk,
and the words are written down as bubbles (speech to text). Tap a bubble to
say it again or pop it. Sheru the Gir lion cub asks questions to help.
There's no keyboard anywhere. Each day becomes a kite in the Uttarayan sky
over the white Rann.

Android only, Flutter. Everything stays on the phone (`diary/` in the app's
documents folder: one JSON file per day plus the photos).

- `flutter analyze && flutter test`: checks and unit tests.
- `flutter test test/preview_test.dart --dart-define=PREVIEW_DIR=/some/dir`
  renders the main screens to PNGs with fake photos and speech.
- `python3 tool/make_sounds.py` regenerates the sound effects and garba
  music loop in `assets/sounds/` (needs numpy). All sounds are synthesised
  here, so no licences apply.
- APKs build in CI (`.github/workflows/flutter-ci.yml`) as a downloadable
  artifact.

Font: Baloo 2 (SIL OFL 1.1, `assets/fonts/OFL.txt`), subset to Latin.
