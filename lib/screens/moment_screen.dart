import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../coach.dart';
import '../diary_store.dart';
import '../models.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../voice.dart';
import '../widgets/mic_button.dart';
import '../widgets/playful.dart';
import '../widgets/sentence_view.dart';
import '../widgets/sheru.dart';
import '../words.dart';

/// Sheru's own questions, for when the coach is offline (and after its
/// questions about the photo run out).
const offlinePrompts = [
  'What is in your photo?',
  'Where were you?',
  'What colours can you see?',
  'Who was with you?',
  'How did you feel? Why?',
  'What could you hear?',
  'What was the best part?',
];

/// What the mic is listening for.
enum _Mode { words, replace, bridge, readBack }

/// Talk about the photo, see it as a Super Sentence, read it back.
enum _Step { talk, polishing, read }

/// Add a moment: pick a photo, talk about it while Sheru asks questions, then
/// read Sheru's Super Sentence back aloud for stars. No keyboard anywhere.
class MomentScreen extends StatefulWidget {
  const MomentScreen({super.key, this.initialPhoto});

  /// For previews: start with this photo already chosen.
  final String? initialPhoto;

  @override
  State<MomentScreen> createState() => _MomentScreenState();
}

class _MomentScreenState extends State<MomentScreen> {
  late String? _photo = widget.initialPhoto;
  String _source = 'camera';
  final _id = DiaryStore.newId();
  _Step _step = _Step.talk;

  // Talking.
  var _words = <String>[];
  String _live = '';
  bool _listening = false;
  _Mode _mode = _Mode.words;
  bool _busy = false;
  double _level = 0;
  int? _selected;
  int? _replacing;
  String? _sheruSays;
  bool _celebrating = false;
  VoiceReady _voiceReady = VoiceReady.ready;

  // Sheru's questions about the photo.
  var _questions = <String>[];
  bool _asked = false;
  bool _thinking = false;
  int _prompt = 0;

  // The Gujarati/Hindi word bridge.
  BridgeWord? _bridged;

  // The Super Sentence and reading it back.
  SuperSentence? _super;
  ReadBack? _read;
  int _bestStars = 0;
  (int, int)? _speaking;

  App get _app => App.of(context);
  bool get _online => _app.coach.online;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVoice());
  }

  @override
  void deactivate() {
    _app.speaker.stop();
    super.deactivate();
  }

  Future<void> _checkVoice() async {
    final ready = await _app.voice.init();
    if (!mounted) return;
    setState(() => _voiceReady = ready);
  }

  List<String> get _prompts => [..._questions, ...offlinePrompts.skip(1)];

  String get _message {
    if (_sheruSays != null) return _sheruSays!;
    if (_voiceReady == VoiceReady.noPermission) return 'Ask a grown-up to let me use the microphone!';
    if (_voiceReady == VoiceReady.unavailable) return "This phone can't turn talking into words yet. Ask a grown-up!";
    switch (_step) {
      case _Step.polishing:
        return "I'm making your Super Sentence...";
      case _Step.read:
        if (_listening) return 'Read it out loud!';
        return 'Here is your Super Sentence! Tap the mic and read it to me.';
      case _Step.talk:
        if (_listening && _mode == _Mode.bridge) return 'Say the word in Gujarati or Hindi!';
        if (_thinking) return 'Hmm, let me look at your photo...';
        if (_replacing != null) return 'Say the new word!';
        if (_words.isEmpty) return offlinePrompts[0];
        return _prompts[_prompt % _prompts.length];
    }
  }

  // --- Photo ------------------------------------------------------------------

  Future<void> _pick(bool camera) async {
    final path = await _app.pickPhoto(camera: camera);
    if (path == null || !mounted) return;
    _app.sounds.play(camera ? Sfx.shutter : Sfx.sparkle);
    setState(() {
      _photo = path;
      _source = camera ? 'camera' : 'gallery';
      _sheruSays = null;
      // A new photo deserves new questions.
      _asked = false;
      _questions = [];
    });
  }

  // --- Listening --------------------------------------------------------------

  void _tapMic() => _listening ? _stopTalking() : _startTalking(_step == _Step.read ? _Mode.readBack : _Mode.words);

  /// Listens until the mic is tapped again. Fixing a word or saying a
  /// Gujarati/Hindi word stops by itself once something is heard; reading
  /// back stops as soon as every word has been read.
  Future<void> _startTalking(_Mode mode) async {
    if (_listening || _busy) return;
    setState(() {
      _mode = mode;
      _listening = true;
      _live = '';
      _sheruSays = null;
      _bridged = null;
      if (mode == _Mode.readBack) _read = null;
    });
    await _app.speaker.stop();
    await _app.sounds.hush();
    await _app.sounds.play(Sfx.listenOn);
    // Let the chime finish so it isn't heard as a word.
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted || !_listening) return;
    final ok = await _app.voice.start(
      onText: _onText,
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
      oneShot: mode == _Mode.replace || mode == _Mode.bridge,
      languages: mode == _Mode.bridge ? const ['gu_IN', 'hi_IN'] : null,
      onEnded: _stopTalking,
    );
    if (!ok && mounted) {
      setState(() {
        _listening = false;
        _sheruSays = mode == _Mode.bridge
            ? "This phone can't hear Gujarati or Hindi yet. Ask a grown-up!"
            : "Oh no, I can't hear right now. Ask a grown-up to help!";
      });
      await _app.sounds.unhush();
      if (mode != _Mode.bridge) unawaited(_checkVoice());
    }
  }

  void _onText(String t) {
    if (!mounted) return;
    setState(() {
      _live = t;
      if (_mode == _Mode.readBack) _read = scoreReading(_super!.text, t);
    });
    if (_mode == _Mode.readBack && _read!.all) _stopTalking();
  }

  Future<void> _stopTalking() async {
    if (!_listening || _busy) return;
    setState(() => _busy = true);
    final said = (await _app.voice.stop()).trim();
    await _app.sounds.unhush();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _busy = false;
      _level = 0;
      _live = '';
    });
    switch (_mode) {
      case _Mode.words:
        _heardWords(said);
      case _Mode.replace:
        _heardReplacement(said);
      case _Mode.bridge:
        await _heardBridge(said);
      case _Mode.readBack:
        _heardReading(said);
    }
  }

  void _nothingHeard() {
    _app.sounds.play(Sfx.oops);
    setState(() {
      _replacing = null;
      _sheruSays = "I didn't hear anything. Tap the mic and talk!";
    });
  }

  void _heardWords(String said) {
    if (said.isEmpty) return _nothingHeard();
    _app.sounds.play(Sfx.sparkle);
    setState(() {
      _words = [..._words, ...splitWords(said)];
      _prompt++;
    });
    // After the first description, Sheru looks at the photo and asks about it.
    if (!_asked && _online) _askCoach();
  }

  Future<void> _askCoach() async {
    _asked = true;
    setState(() => _thinking = true);
    final q = await _app.coach.ask(_photo!, joinWords(_words));
    if (!mounted) return;
    setState(() {
      _thinking = false;
      if (q == null) return;
      _questions = q.questions;
      _prompt = 0;
      _sheruSays = q.praise.isEmpty ? null : '${q.praise} ${q.questions.first}';
    });
  }

  void _heardReplacement(String said) {
    if (said.isEmpty) return _nothingHeard();
    _app.sounds.play(Sfx.sparkle);
    setState(() {
      _words = replaceWord(_words, _replacing!, said);
      _replacing = null;
      _selected = null;
      _sheruSays = 'Fixed it!';
    });
  }

  Future<void> _heardBridge(String said) async {
    if (said.isEmpty) return _nothingHeard();
    setState(() {
      _thinking = true;
      _sheruSays = 'Hmm, "$said"... let me think!';
    });
    final b = await _app.coach.bridge(said);
    if (!mounted) return;
    _app.sounds.play(b == null ? Sfx.oops : Sfx.sparkle);
    setState(() {
      _thinking = false;
      _bridged = b;
      _sheruSays = b == null
          ? "I don't know that one yet. Can you say it another way?"
          : 'In English, that\'s "${b.english}"! ${b.sentence}';
    });
    if (b != null) unawaited(_app.speaker.say('${b.english}. ${b.sentence}'));
  }

  void _addBridged() {
    final b = _bridged!;
    setState(() {
      _words = [..._words, ...splitWords(b.english.toLowerCase())];
      _bridged = null;
      _sheruSays = 'Added "${b.english}" to your words!';
    });
  }

  void _heardReading(String said) {
    if (said.isEmpty) return _nothingHeard();
    final r = scoreReading(_super!.text, said);
    _bestStars = max(_bestStars, r.stars);
    setState(() {
      _read = r;
      _sheruSays = switch (r.stars) {
        3 => 'Wah! You read it all! Three stars!',
        2 => 'So good! Read it once more for three stars?',
        1 => 'Nice try! Listen to me, then read again.',
        _ => "Let's read it together. Tap the speaker to hear it first!",
      };
    });
    if (r.stars == 3) {
      _app.sounds.play(Sfx.dhol);
      ConfettiBurst.show(context);
    } else {
      _app.sounds.play(r.stars > 0 ? Sfx.sparkle : Sfx.oops);
    }
  }

  // --- Fixing words -----------------------------------------------------------

  void _tapWord(int i) {
    if (_listening) return;
    _app.sounds.play(Sfx.pop);
    setState(() {
      _selected = _selected == i ? null : i;
      _replacing = null;
      _sheruSays = _selected == null ? null : 'Say it again, or pop it?';
    });
  }

  void _sayAgain() {
    setState(() => _replacing = _selected);
    _startTalking(_Mode.replace);
  }

  void _popWord() {
    setState(() {
      _words = removeWord(_words, _selected!);
      _selected = null;
      _replacing = null;
      _sheruSays = 'Pop!';
    });
  }

  void _startOver() {
    _app.sounds.play(Sfx.whoosh);
    setState(() {
      _words = [];
      _selected = null;
      _replacing = null;
      _bridged = null;
      _prompt = 0;
      _sheruSays = "Let's start again!";
    });
  }

  // --- The Super Sentence -----------------------------------------------------

  Future<void> _makeSuperSentence() async {
    if (_words.isEmpty || _busy) return;
    final said = joinWords(_words);
    setState(() {
      _step = _Step.polishing;
      _selected = null;
      _bridged = null;
      _sheruSays = null;
    });
    final polished = _online ? await _app.coach.polish(_photo!, said) : null;
    if (!mounted) return;
    _app.sounds.play(Sfx.sparkle);
    setState(() {
      _super = polished ?? offlinePolish(said);
      _step = _Step.read;
      _read = null;
      _bestStars = 0;
      _sheruSays = _super!.praise.isEmpty ? null : '${_super!.praise} Tap the mic and read it to me.';
    });
    unawaited(_hear());
  }

  /// Sheru reads the Super Sentence, lighting up each word.
  Future<void> _hear() async {
    if (_listening || _super == null) return;
    await _app.sounds.hush();
    await _app.speaker.say(
      _super!.text,
      onWord: (start, end) {
        if (mounted) setState(() => _speaking = (start, end));
      },
    );
    await _app.sounds.unhush();
    if (mounted) setState(() => _speaking = null);
  }

  void _sayWord(NewWord w) {
    _app.sounds.play(Sfx.pop);
    _app.speaker.say(w.meaning.isEmpty ? w.word : '${w.word}. ${w.meaning}');
  }

  void _backToTalking() {
    _app.speaker.stop();
    setState(() {
      _step = _Step.talk;
      _sheruSays = 'Add more, or change your words!';
    });
  }

  // --- Saving -----------------------------------------------------------------

  Future<void> _save() async {
    if (_words.isEmpty || _photo == null || _busy) return;
    setState(() => _busy = true);
    await _app.speaker.stop();
    final store = _app.store;
    final now = _app.now();
    final text = tidySentence(joinWords(_words));
    final polished = _super?.text;
    final photo = await store.importPhoto(_photo!, _id);
    await store.addMoment(
      Moment(
        id: _id,
        createdAt: now,
        photo: photo,
        text: text,
        superSentence: polished == null || polished == text ? null : polished,
        newWords: _super?.newWords ?? const [],
        stars: _bestStars,
        source: _source,
      ),
    );
    if (!mounted) return;
    _app.sounds.play(Sfx.dhol);
    ConfettiBurst.show(context);
    setState(() {
      _celebrating = true;
      _sheruSays = 'Shabash! It\'s in your diary!';
    });
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<bool> _confirmLeave() async {
    if (_photo == null && _words.isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => const _BigChoiceDialog(question: 'Leave without saving?'),
    );
    return leave == true;
  }

  // --- Layout -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _celebrating || _step == _Step.polishing) return;
        if (_listening) {
          await _app.voice.cancel();
          setState(() => _listening = false);
          await _app.sounds.unhush();
        }
        if (_step == _Step.read) return _backToTalking();
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        body: BandhaniBackground(
          child: SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(child: _photo == null ? _choosePhoto() : _withDock()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          BlobButton(
            icon: Icons.arrow_back_rounded,
            color: Gj.peacock,
            size: 56,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(child: OutlinedTitle(_step == _Step.talk ? 'New moment' : 'Super Sentence', size: 30)),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _choosePhoto() {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SheruSays('Show me what you saw today!', size: 120),
              const SizedBox(height: 24),
              _PhotoChoice(
                color: Gj.saffron,
                icon: Icons.photo_camera_rounded,
                label: 'Take a photo',
                onTap: () => _pick(true),
              ),
              const SizedBox(height: 20),
              _PhotoChoice(
                color: Gj.peacock,
                icon: Icons.photo_library_rounded,
                label: 'Pick a photo',
                onTap: () => _pick(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The page scrolls under a floating dock with the mic in the middle.
  Widget _withDock() {
    final canTalk = _voiceReady == VoiceReady.ready && !_celebrating;
    final Widget dock = switch (_step) {
      _Step.talk => _fixingWord ? _wordActions(canTalk) : _talkDock(canTalk),
      _Step.polishing => const SizedBox(height: 150),
      _Step.read => _readDock(canTalk),
    };
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            // Room at the bottom so nothing hides under the floating mic.
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 220),
            child: _step == _Step.talk ? _talkPage() : _readPage(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Gj.sand.withValues(alpha: 0), Gj.sand.withValues(alpha: 0.95), Gj.sand],
                stops: const [0, 0.35, 1],
              ),
            ),
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 10), child: dock),
          ),
        ),
      ],
    );
  }

  Widget _photoCard(double heightFraction, {bool canChange = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The frame is 4:3 plus its white border, so limit its width to fit the height.
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).height * heightFraction - 26) * 4 / 3 + 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Polaroid(image: FileImage(File(_photo!)), tilt: -0.03),
            ),
          ),
        ),
        if (canChange)
          Positioned(
            right: -6,
            bottom: -10,
            child: BlobButton(
              icon: Icons.cached_rounded,
              color: Gj.lilac,
              size: 50,
              onTap: () => setState(() => _photo = null),
            ),
          ),
      ],
    );
  }

  Widget _sheru() => SheruSays(
    _message,
    size: 84,
    listening: _listening,
    level: _level,
    happy: _celebrating || (_step == _Step.read && (_read?.stars ?? 0) == 3),
  );

  Widget _talkPage() {
    final live = splitWords(_live);
    return Column(
      children: [
        _photoCard(0.34, canChange: !_listening && !_celebrating),
        const SizedBox(height: 18),
        _sheru(),
        if (_online && !_listening && !_thinking && _bridged == null && _selected == null) ...[
          const SizedBox(height: 10),
          _BridgeButton(onTap: () => _startTalking(_Mode.bridge)),
        ],
        if (_bridged != null) ...[const SizedBox(height: 10), _bridgeCard()],
        const SizedBox(height: 12),
        _wordBoard(live),
      ],
    );
  }

  Widget _bridgeCard() {
    final b = _bridged!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Gj.teal, width: 3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.english, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Gj.teal, height: 1.1)),
                if (b.sentence.isNotEmpty)
                  Text(b.sentence, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Gj.ink)),
              ],
            ),
          ),
          BlobButton(icon: Icons.add_rounded, color: Gj.teal, size: 54, label: 'Add it', onTap: _addBridged),
        ],
      ),
    );
  }

  Widget _readPage() {
    final s = _super;
    return Column(
      children: [
        _photoCard(0.22),
        const SizedBox(height: 16),
        _sheru(),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: s == null
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(color: Gj.saffron, strokeWidth: 6),
                )
              : Container(
                  key: const ValueKey('super'),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Gj.marigold, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Gj.saffron),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Super Sentence',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Gj.saffron),
                            ),
                          ),
                          if (!_listening)
                            BlobButton(icon: Icons.edit_rounded, color: Gj.lilac, size: 44, onTap: _backToTalking),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SentenceView(text: s.text, newWords: s.newWords, matched: _read?.matched, speaking: _speaking),
                      if (_read != null || _bestStars > 0) ...[
                        const SizedBox(height: 10),
                        Center(child: StarRow(_read?.stars ?? _bestStars)),
                      ],
                    ],
                  ),
                ),
        ),
        if (s != null && s.newWords.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: OutlinedTitle('New words', size: 22, color: Gj.saffron, stroke: 5),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final w in s.newWords) NewWordChip(word: w, onTap: () => _sayWord(w))],
          ),
        ],
      ],
    );
  }

  bool get _fixingWord => _selected != null && !_listening && _replacing == null;

  /// Again · mic · Done.
  Widget _talkDock(bool canTalk) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _side(
          BlobButton(
            icon: Icons.replay_rounded,
            color: Gj.kumkum,
            label: 'Again',
            onTap: _words.isEmpty || _listening || _celebrating ? null : _startOver,
          ),
        ),
        MicButton(listening: _listening, level: _level, enabled: canTalk && !_busy, onTap: _tapMic),
        _side(
          BlobButton(
            icon: Icons.check_rounded,
            color: Gj.leaf,
            label: 'Done',
            sound: Sfx.sparkle,
            onTap: _words.isEmpty || _listening || _busy || _thinking ? null : _makeSuperSentence,
          ),
        ),
      ],
    );
  }

  /// With a word picked: Pop it · mic to say it again · Keep.
  Widget _wordActions(bool canTalk) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _side(BlobButton(icon: Icons.bubble_chart_rounded, color: Gj.kumkum, label: 'Pop it', onTap: _popWord)),
        MicButton(listening: false, level: 0, enabled: canTalk && !_busy, idleLabel: 'Say it again', onTap: _sayAgain),
        _side(
          BlobButton(
            icon: Icons.close_rounded,
            color: Gj.inkSoft,
            label: 'Keep',
            onTap: () => setState(() {
              _selected = null;
              _sheruSays = null;
            }),
          ),
        ),
      ],
    );
  }

  /// Hear it · mic to read it · Save.
  Widget _readDock(bool canTalk) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _side(
          BlobButton(
            icon: Icons.volume_up_rounded,
            color: Gj.teal,
            label: 'Hear it',
            onTap: _listening || _celebrating || _speaking != null ? null : _hear,
          ),
        ),
        MicButton(
          listening: _listening,
          level: _level,
          enabled: canTalk && !_busy,
          idleLabel: _read == null ? 'Read it to me' : 'Read it again',
          onTap: _tapMic,
        ),
        _side(
          BlobButton(
            icon: Icons.check_rounded,
            color: Gj.leaf,
            label: 'Save',
            sound: Sfx.sparkle,
            onTap: _listening || _busy || _celebrating ? null : _save,
          ),
        ),
      ],
    );
  }

  Widget _side(Widget child) => Padding(padding: const EdgeInsets.only(bottom: 34), child: child);

  Widget _wordBoard(List<String> live) {
    final empty = _words.isEmpty && live.isEmpty;
    final showLive = _mode == _Mode.words || _mode == _Mode.replace;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Gj.marigold, width: 3),
        ),
        child: empty
            ? const Center(
                child: Text(
                  'Your words will pop up here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Gj.inkSoft),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < _words.length; i++)
                    _PoppingIn(
                      key: ValueKey('w$i${_words[i]}'),
                      child: WordBubble(
                        word: _replacing == i && _listening ? '...' : _words[i],
                        color: Gj.festive[i % Gj.festive.length],
                        selected: _selected == i,
                        onTap: () => _tapWord(i),
                      ),
                    ),
                  if (showLive && _replacing == null)
                    for (var i = 0; i < live.length; i++)
                      WordBubble(word: live[i], color: Gj.festive[(_words.length + i) % Gj.festive.length], live: true),
                  if (showLive && _replacing != null && live.isNotEmpty)
                    WordBubble(word: live.join(' '), color: Gj.kumkum, live: true),
                  if (_mode == _Mode.bridge && live.isNotEmpty) WordBubble(word: live.join(' '), color: Gj.teal, live: true),
                ],
              ),
      ),
    );
  }
}

/// "I know it in Gujarati!": say a word in Gujarati or Hindi, get it in English.
class _BridgeButton extends StatelessWidget {
  const _BridgeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        App.of(context).sounds.play(Sfx.pop);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Gj.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Gj.teal, width: 2.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate_rounded, color: Gj.teal),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'I know it in Gujarati or Hindi!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Gj.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoChoice extends StatelessWidget {
  const _PhotoChoice({required this.color, required this.icon, required this.label, required this.onTap});
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KutchButton(label: label, icon: icon, color: color, height: 104, fontSize: 30, onTap: onTap);
  }
}

/// New word bubbles bounce in.
class _PoppingIn extends StatelessWidget {
  const _PoppingIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: child,
    );
  }
}

/// A yes/no question answered with two big picture buttons.
class _BigChoiceDialog extends StatelessWidget {
  const _BigChoiceDialog({required this.question});
  final String question;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Gj.sand,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Sheru(size: 96),
            const SizedBox(height: 8),
            Text(
              question,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Gj.ink, height: 1.1),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                BlobButton(
                  icon: Icons.close_rounded,
                  color: Gj.kumkum,
                  size: 72,
                  label: 'No',
                  onTap: () => Navigator.of(context).pop(false),
                ),
                BlobButton(
                  icon: Icons.check_rounded,
                  color: Gj.leaf,
                  size: 72,
                  label: 'Yes',
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared with the day screen.
Future<bool> askYesNo(BuildContext context, String question) async =>
    await showDialog<bool>(context: context, builder: (_) => _BigChoiceDialog(question: question)) ?? false;
