# Changelog

## [0.7.4] - 2026-10-27

### Changed
- Passport stamps come from two things together: where the photo was taken
  (GPS) and the places named in the child's words. Either one is enough.
- A close mention counts as a match. "Modhera Temple" stamps Modhera Sun
  Temple, "Gir" stamps Gir Forest, and a slipped letter ("Modera") is fine.
  Words like temple, forest, fort and "Sun" are not needed to match.

### Fixed
- The microphone is made ready when the app opens, so the first tap on it
  starts listening straight away.
- Speech problems (errors, a slow start, slow first words) are now written to
  the crash note in Download, so a voice problem can be traced.

## [0.7.3] - 2026-10-27

### Fixed
- The 0.7.0 to 0.7.2 builds never started because of a GitHub billing limit,
  so none were published. This version has the same changes: phone-number
  text-code sync, stamps from the child's own words, kite dates for older days.

## [0.7.2] - 2026-10-27

### Fixed
- The 0.7.0 and 0.7.1 builds stopped at the code check and were never
  published. This version has the same changes (phone-number text-code sync,
  stamps from the child's own words, kite dates for older days) and passes.

## [0.7.1] - 2026-10-27

### Added
- Add a picture from an older day. Today is picked to start, with a row of
  kites for the last week (each with its weekday and date) and an Older kite
  that opens any month as kites. The chosen day is spelled out ("Saturday,
  24 October", "3 days ago") so it is easy to tell which one it is.

### Changed
- Passport stamps now come from the places named in the child's own words, not
  from the photo's GPS, which can be off. Because the words sync, every phone
  shows the same stamps.

## [0.7.0] - 2026-10-27

### Added
- Sync the diary across phones from the grown-ups' corner. Sign in with a
  one-time text code (SMS OTP) sent to the same phone number on every phone.
  Each phone does a one-time choice of which entries to add; after that new
  entries and deletions sync by themselves.

### Fixed
- Map stamps now match on every synced phone. An entry that was saved without
  a place gets one from its photo's own GPS tag, the place is sent to the
  other phones, and a place found on one phone unlocks on the rest.

## [0.6.1] - 2026-10-22

### Fixed
- Saying a word in Bengali or Hindi: the app no longer gives up when the
  phone's speech recogniser leaves the language off its list (it often
  lists only some of what it can hear). It now asks for the language anyway.
- If the phone really can't hear that language, Sheru says so and how a
  grown-up can add it (the phone's voice typing settings), instead of "I
  didn't hear anything". The note in Download lists the languages the phone
  does offer.

## [0.6.0] - 2026-10-22

### Added
- Sheru is the app icon now, on a sky-blue background, in place of the
  Flutter logo.
- Pick the music: the music button opens a choice of Garba, Block World (a
  calm piano tune in the mood of block-building games), Obby Dash (a bouncy
  chiptune in the mood of obstacle-course games), or no music. Both new
  tunes are our own, made for the diary.
- My own song: in the grown-ups' corner, pick any music file on the phone
  to play instead. It's copied into the app and never leaves the phone.
- Check for updates: a button in the grown-ups' corner asks for a new
  version straight away, then downloads and installs it in place.
- How to Use has a Music page, and the grown-ups page lists the new
  settings.

### Changed
- Updates come only from chosen releases now, not from every change, so the
  phone only gets finished versions. The update notes are this changelog.

## [0.5.1] - 2026-10-22

### Fixed
- Bengali and Hindi to English work again. In 0.5.0 the release build's
  code shrinker broke Google's on-phone translator, so every try failed and
  Sheru wrongly said the internet was needed.
- If translation ever fails, Sheru no longer blames the internet unless
  that's likely, and the note in Download now says exactly where it broke.

## [0.5.0] - 2026-10-22

### Added
- Share my day: the green share button on a day makes a picture postcard,
  a comic strip, or a storybook to print (this day, or the whole trip),
  ready for WhatsApp, Drive or printing. Postcards and comics can also be
  saved straight into the phone's photos.
- How did you feel? Once there are words, six faces to pick from. Sheru
  then asks "why?", to practise "I felt ... because ...". The face shows on
  the day's page and in the storybook.
- Tell me more: See, Hear, Smell, Touch and Taste buttons give Sheru's
  questions for describing a photo, not just naming it.
- Places and fun facts: the diary works out where each photo was taken
  (from the photo itself, or where the phone is for a new photo), on the
  phone and offline. Tap the place on the photo to hear a fun fact about
  it: 33 Gujarat districts, 18 famous sights and 13 places around India.
- My Passport (the Map button): a cartoon map of Gujarat where every new
  place gets a stamp, and a page of famous-place stamps to collect.
- Read me my day: the moon button on a day has Sheru read every page aloud,
  turning to each one in turn.
- Today's kite flies higher as the diary grows ("Diary day 5"); a missed
  day never takes anything away.
- Grown-ups' corner (hold the lock by the date for 3 seconds, then answer a
  sum): music and sound effects switches, progress charts (words per
  picture, describing words, new words), a backup of the whole diary as one
  .zip, adding a backup to this phone, and deleting a day.
- How to Use has new pages for all of these.

### Changed
- The app asks once for a rough location, only to name the place a photo
  was taken. Nothing leaves the phone.

## [0.4.3] - 2026-10-22

### Fixed
- Bengali and Hindi to English works: the translation add-on never
  connected on the phone (every try failed). It's replaced by the app's own
  bridge to Google's on-phone translator, which also reports exactly what
  went wrong if it ever fails.
- A few taps that could land just as a word bubble closed no longer cause
  an error.

### Changed
- Faster everywhere:
  - Photos are decoded at the size they're shown, not their full size.
  - The patterned backgrounds and the sky are drawn once and reused, not
    redrawn on every animation frame.
  - The button sparkles, kites and mic animate in their own layers.
  - Diary days are kept in memory after the first read.
  - Sheru's voice gets ready in the background, so he speaks straight away.
  - Startup does its steps together.
- New photos are saved at up to 1600 px (was 2048): quicker to save and show.
- Crash notes name the functions involved.

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
