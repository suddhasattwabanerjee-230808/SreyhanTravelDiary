# Changelog

## [0.4.2] - 2026-10-22

### Fixed
- The sentence no longer shows up again and again after talking. When the
  phone's speech recogniser sent the same words twice (after a pause, or
  after the mic stopped), each copy was added as more bubbles. Now each bit
  of speech becomes bubbles once.

## [0.4.1] - 2026-10-22

### Fixed
- 0.4.0 stopped at a black screen. Startup waited on the shared_preferences
  plugin, which never answers in release builds. Settings are now kept by
  Android directly, every startup step has a time limit, and the diary
  always opens.
- If something goes wrong, a note is saved in Download
  (`SreyhanDiary-crash-…`), including why the last run ended if it crashed
  or froze. Speech, reading aloud, photo labels and translation can no
  longer hang the app either.

### Added
- How to Use: a picture guide to every part of the app, read aloud by
  Sheru. It opens by itself the first time; the ? button on the home screen
  brings it back.

## [0.4.0] - 2026-10-22

### Added
- In-app updates: the app checks for a new version at launch, shows a
  "New diary update!" card on the home screen, and installs it in place.

### Changed
- Much smaller APK: release build (ahead-of-time compiled, unused code and
  icons stripped), arm64 libraries only and compressed, sounds as OGG instead
  of WAV (944 KB to 144 KB), and the photo-labelling model comes from Google
  Play services instead of being bundled.
- The big "Today" kite shrinks to fit smaller screens.

## [0.3.0] - 2026-10-22

### Added
- Games corner with four games made from the child's own diary:
  - **Which Photo?**: Sheru reads one of their sentences; tap its photo.
  - **Kite Spell**: tap letter kites in order to spell a word from the trip.
  - **Sentence Train**: put a jumbled diary sentence's carriages in order.
  - **Travel I-Spy**: a daily bingo card of nine things to find; squares
    stamp themselves when a photo shows them.
- Tap a word bubble to fix it with the keyboard (or pop it, or say it again).
- Say a word in Bengali or Hindi to get it in English (on-device ML Kit
  translation); added words fill the Word Jar.
- Sheru's questions now come from what the phone sees in the photo
  (on-device ML Kit labels), e.g. "I see a camel! What colour was it?".

### Removed
- The Super Sentence, read-back stars and the Claude coach (coach-worker):
  everything now runs free on the phone.
- Gujarati word bridge (replaced by Bengali and Hindi).

### Changed
- Sheru speaks English only ("Hello" and "Well done" instead of "Kem cho"
  and "Shabash").

## [0.2.0] - 2026-10-22

### Added
- Sheru's coach (Claude, through the `coach-worker` Cloudflare Worker): after
  the child describes the photo, Sheru looks at it and asks 2-3 questions
  about what's in it.
- Super Sentence: tapping Done turns the child's words into 1-3 diary
  sentences with new words highlighted. Sheru reads it aloud, lighting up each
  word, then the child reads it back with the mic: words turn green as they're
  read, for up to three stars.
- Word bridge: "I know it in Gujarati or Hindi!" listens in Gujarati (or
  Hindi) and gives the English word, ready to add.
- Word Jar: every new word, with the photo it came from; tap to hear it.
- Day pages show the Super Sentence, the child's own words, new words, stars,
  and a button to hear the page read aloud.
- Works offline: without the coach, Sheru uses built-in questions and the
  Super Sentence is the child's own words, tidied.

### Changed
- Round buttons now respond to taps on their label too.
- Every build is signed with one fixed key, so updates install over the old
  app. The newest APK is published to the repo's Releases page.

## [0.1.0] - 2026-10-22

### Added
- Sky of Kites home: today's kite to fill, earlier days as smaller kites.
- New moment: take or pick a photo, then tap the floating mic and talk.
  Speech becomes text live, as word bubbles; tap the mic again to stop.
  Tap a word to say it again (listening stops by itself) or pop it.
  No keyboard anywhere.
- Day scrapbook: taped-in photos with the child's sentences.
- Synthesised dhol, kite whoosh, sparkle and a garba music loop, with a music
  switch.
