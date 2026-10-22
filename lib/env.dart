/// The coach Worker (coach-worker/worker.js) and the token it expects.
/// Passed at build time, from the COACH_URL and COACH_TOKEN repo secrets:
///   flutter build apk --dart-define=COACH_URL=... --dart-define=COACH_TOKEN=...
/// Without them the app runs fully offline, with Sheru's own questions.
const coachUrl = String.fromEnvironment('COACH_URL');
const coachToken = String.fromEnvironment('COACH_TOKEN');
