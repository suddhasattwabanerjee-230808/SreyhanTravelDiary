import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../diary_store.dart';
import '../feelings.dart';
import '../models.dart';
import '../places.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../translate.dart';
import '../vision.dart';
import '../voice.dart';
import '../widgets/mic_button.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';
import '../widgets/stamp.dart';
import '../words.dart';

/// Sheru's own questions, after his questions about the photo run out.
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
enum _Mode { words, replace, bridge }

/// Add a moment: pick a photo, then talk about it while Sheru asks questions
/// about what's in it. Words appear as bubbles; tap one to fix it with the
/// keyboard. Say a word in Bengali or Hindi to get it in English. Once there
/// are words, faces and the five senses give ideas for saying more, and the
/// photo's place (if the phone knows it) comes with a fun fact.
class MomentScreen extends StatefulWidget {
  const MomentScreen({super.key, this.initialPhoto});

  /// For previews: start with this photo already chosen.
  final String? initialPhoto;

  @override
  State<MomentScreen> createState() => _MomentScreenState();
}

class _MomentScreenState extends State<MomentScreen> {
  String? _photo;
  String _source = 'camera';
  final _id = DiaryStore.newId();

  // What's in the photo, and Sheru's questions about it.
  var _labels = <String>[];
  var _questions = <String>[];
  int _prompt = 0;

  // Where it was taken, and how the child felt.
  Place? _place;
  Feeling? _feeling;

  // Talking.
  var _words = <String>[];
  String _live = '';
  bool _listening = false;
  _Mode _mode = _Mode.words;
  bool _busy = false;
  double _level = 0;
  int? _replacing;
  String? _sheruSays;
  bool _celebrating = false;
  VoiceReady _voiceReady = VoiceReady.ready;

  // Fixing a bubble with the keyboard.
  int? _editing;
  final _editText = TextEditingController();
  final _editFocus = FocusNode();
  final _editKey = GlobalKey();

  // Bengali/Hindi to English.
  HomeLanguage? _bridgeLang;
  bool _preparing = false;
  LearnedWord? _bridged;
  final _learned = <LearnedWord>[];

  App get _app => App.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVoice();
      if (widget.initialPhoto != null) _usePhoto(widget.initialPhoto!, 'camera');
    });
  }

  @override
  void dispose() {
    _editText.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  Future<void> _checkVoice() async {
    final ready = await _app.voice.init();
    if (!mounted) return;
    setState(() => _voiceReady = ready);
  }

  String get _message {
    if (_sheruSays != null) return _sheruSays!;
    if (_voiceReady == VoiceReady.noPermission) return 'Ask a grown-up to let me use the microphone!';
    if (_voiceReady == VoiceReady.unavailable) return "This phone can't turn talking into words yet. Ask a grown-up!";
    if (_listening && _mode == _Mode.bridge) return 'Say the word in ${_bridgeLang!.name}!';
    if (_editing != null) return 'Fix the spelling, or type a new word!';
    if (_replacing != null) return 'Say the new word!';
    if (_words.isEmpty) {
      final seen = _labels.where((l) => thingOf(l) != null).firstOrNull;
      return seen == null ? offlinePrompts[0] : 'I think I see ${seen.toLowerCase()}! Tell me about your photo.';
    }
    final prompts = [..._questions, ...offlinePrompts.skip(1)];
    return prompts[(_prompt - 1) % prompts.length];
  }

  // --- Photo ------------------------------------------------------------------

  Future<void> _pick(bool camera) async {
    final path = await _app.pickPhoto(camera: camera);
    if (path == null || !mounted) return;
    _app.sounds.play(camera ? Sfx.shutter : Sfx.sparkle);
    _usePhoto(path, camera ? 'camera' : 'gallery');
  }

  /// Shows the photo straight away; Sheru's questions follow once the phone
  /// has looked at it.
  Future<void> _usePhoto(String path, String source) async {
    setState(() {
      _photo = path;
      _source = source;
      _sheruSays = null;
      _labels = [];
      _questions = [];
      _place = null;
    });
    _findPlace(path, source == 'camera');
    final labels = await _app.labeler.labels(path);
    if (!mounted || _photo != path) return;
    setState(() {
      _labels = labels;
      _questions = photoQuestions(labels);
    });
  }

  Future<void> _findPlace(String path, bool camera) async {
    final place = await _app.places.find(path, camera: camera);
    if (!mounted || _photo != path || place == null) return;
    setState(() => _place = place);
  }

  /// Sheru says something out loud as well as in his bubble.
  void _tell(String text) {
    if (_listening) return;
    _commitEdit();
    setState(() => _sheruSays = text);
    unawaited(_app.speaker.say(text));
  }

  void _tellPlace() {
    final p = _place;
    if (p != null) _tell('${p.name}! ${p.fact}');
  }

  void _pickFeeling(Feeling f) {
    _app.sounds.play(Sfx.pop);
    if (_feeling == f) {
      setState(() => _feeling = null);
      return;
    }
    setState(() => _feeling = f);
    _tell(f.why);
  }

  void _askSense(Sense s) => _tell(s.question);

  // --- Listening --------------------------------------------------------------

  void _tapMic() => _listening ? _stopTalking() : _startTalking(_Mode.words);

  /// Listens until the mic is tapped again. Fixing a word or saying a
  /// Bengali/Hindi word stops by itself once something is heard.
  Future<void> _startTalking(_Mode mode) async {
    if (_listening || _busy) return;
    _commitEdit();
    setState(() {
      _mode = mode;
      _listening = true;
      _live = '';
      _sheruSays = null;
      _bridged = null;
    });
    await _app.speaker.stop();
    await _app.sounds.hush();
    await _app.sounds.play(Sfx.listenOn);
    // Let the chime finish so it isn't heard as a word.
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted || !_listening) return;
    final ok = await _app.voice.start(
      onText: (t) {
        // Words that turn up after the mic stopped are already in the bubbles.
        if (mounted && _listening) setState(() => _live = t);
      },
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
      oneShot: mode != _Mode.words,
      languages: mode == _Mode.bridge ? _bridgeLang!.speechLocales : null,
      onEnded: _stopTalking,
    );
    if (!ok && mounted) {
      setState(() {
        _listening = false;
        _replacing = null;
        _sheruSays = mode == _Mode.bridge
            ? "This phone can't hear ${_bridgeLang!.name} yet. Ask a grown-up!"
            : "Oh no, I can't hear right now. Ask a grown-up to help!";
      });
      await _app.sounds.unhush();
      if (mode != _Mode.bridge) unawaited(_checkVoice());
    }
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
    if (said.isEmpty) {
      _app.sounds.play(Sfx.oops);
      setState(() {
        _replacing = null;
        _sheruSays = "I didn't hear anything. Tap the mic and talk!";
      });
      return;
    }
    switch (_mode) {
      case _Mode.words:
        _app.sounds.play(Sfx.sparkle);
        setState(() {
          _words = [..._words, ...splitWords(said)];
          _prompt++;
        });
      case _Mode.replace:
        _app.sounds.play(Sfx.sparkle);
        setState(() {
          final r = _replacing;
          _words = r == null || r >= _words.length ? [..._words, ...splitWords(said)] : replaceWord(_words, r, said);
          _replacing = null;
          _sheruSays = 'Fixed it!';
        });
      case _Mode.bridge:
        await _translate(said);
    }
  }

  // --- Fixing a bubble --------------------------------------------------------

  void _tapWord(int i) {
    if (_listening) return;
    if (_editing == i) return;
    _commitEdit();
    _app.sounds.play(Sfx.pop);
    _editText.text = _words[i];
    _editText.selection = TextSelection.collapsed(offset: _editText.text.length);
    setState(() {
      _editing = i;
      _sheruSays = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocus.requestFocus();
      // Once the keyboard is up, keep the word being fixed in view.
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = _editKey.currentContext;
        if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 250));
      });
    });
  }

  /// Keeps what was typed. An emptied bubble disappears; typing a space
  /// makes two bubbles.
  void _commitEdit() {
    final i = _editing;
    if (i == null) return;
    setState(() {
      if (i < _words.length) _words = replaceWord(_words, i, _editText.text);
      _editing = null;
    });
    _editFocus.unfocus();
  }

  // A tap can land just as the bubble closes: check before using it.
  void _popEditing() {
    final i = _editing;
    if (i == null || i >= _words.length) return;
    _editFocus.unfocus();
    setState(() {
      _words = removeWord(_words, i);
      _editing = null;
      _sheruSays = 'Pop!';
    });
  }

  void _sayEditing() {
    final i = _editing;
    if (i == null || i >= _words.length) return;
    _editFocus.unfocus();
    setState(() {
      _editing = null;
      _replacing = i;
    });
    _startTalking(_Mode.replace);
  }

  void _startOver() {
    _app.sounds.play(Sfx.whoosh);
    setState(() {
      _words = [];
      _editing = null;
      _replacing = null;
      _bridged = null;
      _prompt = 0;
      _sheruSays = "Let's start again!";
    });
  }

  // --- Bengali/Hindi to English -----------------------------------------------

  Future<void> _bridge(HomeLanguage lang) async {
    _commitEdit();
    _bridgeLang = lang;
    if (!await _app.translator.isReady(lang)) {
      setState(() {
        _preparing = true;
        _sheruSays = 'Getting ${lang.name} ready... only the first time!';
      });
      final ok = await _app.translator.prepare(lang);
      if (!mounted) return;
      setState(() => _preparing = false);
      if (!ok) {
        _app.sounds.play(Sfx.oops);
        // Usually no internet for the one-time download, but not always.
        setState(() => _sheruSays = "I can't do ${lang.name} right now. Is the internet on? Ask a grown-up!");
        return;
      }
    }
    await _startTalking(_Mode.bridge);
  }

  Future<void> _translate(String said) async {
    final lang = _bridgeLang!;
    setState(() => _sheruSays = 'Hmm, "$said"... let me think!');
    final english = await _app.translator.toEnglish(said, lang);
    if (!mounted) return;
    _app.sounds.play(english == null ? Sfx.oops : Sfx.sparkle);
    setState(() {
      _bridged = english == null ? null : LearnedWord(english, said, lang.name);
      _sheruSays = english == null
          ? "I couldn't find that one. Can you say it again?"
          : '"$said" in English is "$english"!';
    });
    if (english != null) unawaited(_app.speaker.say(english));
  }

  void _addBridged() {
    final b = _bridged;
    if (b == null) return;
    setState(() {
      _words = [..._words, ...splitWords(b.word)];
      if (!_learned.any((w) => bareWord(w.word) == bareWord(b.word))) _learned.add(b);
      _bridged = null;
      _sheruSays = 'Added "${b.word}"! It\'s in your Word Jar too.';
    });
  }

  // --- Saving -----------------------------------------------------------------

  Future<void> _save() async {
    _commitEdit();
    if (_words.isEmpty || _photo == null || _busy) return;
    setState(() => _busy = true);
    await _app.speaker.stop();
    final store = _app.store;
    // Somewhere not stamped before earns a new stamp in the passport.
    final before = passportStamps([
      for (final d in await store.allDays())
        for (final m in d.moments) ?m.place,
    ]);
    final newStamp = _place != null && !before.contains(_place!.id);
    final photo = await store.importPhoto(_photo!, _id);
    await store.addMoment(
      Moment(
        id: _id,
        createdAt: _app.now(),
        photo: photo,
        text: tidySentence(joinWords(_words)),
        labels: _labels,
        learned: List.of(_learned),
        source: _source,
        feeling: _feeling?.name,
        place: _place?.id,
      ),
    );
    if (!mounted) return;
    _app.sounds.play(Sfx.dhol);
    ConfettiBurst.show(context);
    setState(() {
      _celebrating = true;
      _sheruSays = newStamp
          ? 'Well done! And a new stamp in your passport: ${_place!.name}!'
          : "Well done! It's in your diary!";
    });
    await Future.delayed(Duration(milliseconds: newStamp ? 2600 : 1800));
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
        if (didPop || _celebrating) return;
        if (_editing != null) return _commitEdit();
        if (_listening) {
          await _app.voice.cancel();
          setState(() => _listening = false);
          await _app.sounds.unhush();
        }
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        body: BandhaniBackground(
          child: SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(child: _photo == null ? _choosePhoto() : _talk()),
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
          const Expanded(child: Center(child: OutlinedTitle('New moment', size: 30))),
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

  /// The page scrolls under a floating dock: the mic, or the editing tools
  /// while a bubble is being fixed.
  Widget _talk() {
    final canTalk = _voiceReady == VoiceReady.ready && !_celebrating && !_preparing;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            // Room at the bottom so nothing hides under the floating mic.
            padding: EdgeInsets.fromLTRB(24, 18, 24, keyboardUp ? 120 : 220),
            child: Column(
              children: [
                _photoCard(),
                const SizedBox(height: 18),
                SheruSays(_message, size: 84, listening: _listening, level: _level, happy: _celebrating),
                if (!_listening && _editing == null && _bridged == null && !_celebrating) ...[
                  const SizedBox(height: 10),
                  _BridgeButtons(enabled: canTalk && !_busy, onTap: _bridge),
                ],
                if (_bridged != null) ...[const SizedBox(height: 10), _bridgeCard()],
                const SizedBox(height: 12),
                _wordBoard(),
                if (_words.isNotEmpty && !_listening && _editing == null && !_celebrating) ...[
                  const SizedBox(height: 14),
                  _TalkIdeas(feeling: _feeling, onFeeling: _pickFeeling, onSense: _askSense),
                ],
              ],
            ),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
              child: _editing != null ? _editTools() : _talkDock(canTalk),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.34),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Polaroid(image: FileImage(File(_photo!)), tilt: -0.03),
          ),
        ),
        if (_place != null)
          Positioned(
            left: 0,
            bottom: -12,
            right: 60,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PlacePill(_place!, size: 17, onTap: _tellPlace),
            ),
          ),
        if (!_listening && !_celebrating && _editing == null)
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
            child: GestureDetector(
              onTap: () => _app.speaker.say(b.word),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.from, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Gj.inkSoft)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          b.word,
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Gj.teal, height: 1.1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.volume_up_rounded, color: Gj.teal),
                    ],
                  ),
                ],
              ),
            ),
          ),
          BlobButton(
            icon: Icons.close_rounded,
            color: Gj.inkSoft,
            size: 48,
            label: 'No',
            onTap: () => setState(() {
              _bridged = null;
              _sheruSays = null;
            }),
          ),
          const SizedBox(width: 8),
          BlobButton(icon: Icons.add_rounded, color: Gj.teal, size: 56, label: 'Add it', onTap: _addBridged),
        ],
      ),
    );
  }

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
            onTap: _words.isEmpty || _listening || _busy || _celebrating ? null : _save,
          ),
        ),
      ],
    );
  }

  /// While fixing a bubble: Pop it · Say it · OK, small enough to sit above
  /// the keyboard.
  Widget _editTools() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        BlobButton(icon: Icons.bubble_chart_rounded, color: Gj.kumkum, size: 52, label: 'Pop it', onTap: _popEditing),
        BlobButton(icon: Icons.mic_rounded, color: Gj.saffron, size: 52, label: 'Say it', onTap: _sayEditing),
        BlobButton(icon: Icons.check_rounded, color: Gj.leaf, size: 52, label: 'OK', onTap: _commitEdit),
      ],
    );
  }

  Widget _side(Widget child) => Padding(padding: const EdgeInsets.only(bottom: 34), child: child);

  Widget _wordBoard() {
    final live = splitWords(_live);
    final empty = _words.isEmpty && live.isEmpty;
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < _words.length; i++)
                    if (_editing == i)
                      _EditBubble(
                        key: _editKey,
                        controller: _editText,
                        focusNode: _editFocus,
                        color: Gj.festive[i % Gj.festive.length],
                        onDone: _commitEdit,
                      )
                    else
                      _PoppingIn(
                        key: ValueKey('w$i${_words[i]}'),
                        child: WordBubble(
                          word: _replacing == i && _listening ? '...' : _words[i],
                          color: Gj.festive[i % Gj.festive.length],
                          onTap: () => _tapWord(i),
                        ),
                      ),
                  if (_mode == _Mode.words)
                    for (var i = 0; i < live.length; i++)
                      WordBubble(word: live[i], color: Gj.festive[(_words.length + i) % Gj.festive.length], live: true),
                  if (_mode == _Mode.replace && live.isNotEmpty) WordBubble(word: live.join(' '), color: Gj.kumkum, live: true),
                  if (_mode == _Mode.bridge && live.isNotEmpty) WordBubble(word: live.join(' '), color: Gj.teal, live: true),
                ],
              ),
      ),
    );
  }
}

/// Ideas for saying more: how it felt (a face to pick, then "why?") and the
/// five senses.
class _TalkIdeas extends StatelessWidget {
  const _TalkIdeas({required this.feeling, required this.onFeeling, required this.onSense});
  final Feeling? feeling;
  final void Function(Feeling) onFeeling;
  final void Function(Sense) onSense;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Gj.inkSoft, height: 1.1);
    const small = TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Gj.inkSoft, height: 1.1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Gj.lilac.withValues(alpha: 0.6), width: 3),
      ),
      child: Column(
        children: [
          const Text('How did you feel?', style: label),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final f in Feeling.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: feeling == f,
                    label: f.word,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onFeeling(f),
                      child: Column(
                        children: [
                          AnimatedScale(
                            scale: feeling == f ? 1.18 : (feeling == null ? 1 : 0.86),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: feeling == f ? Gj.edge(f.color) : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: FeelingFace(f, size: 40),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              f.word,
                              style: small.copyWith(color: feeling == f ? Gj.edge(f.color) : Gj.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Tell me more!', style: label),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final s in Sense.values)
                Expanded(
                  child: Center(
                    child: BlobButton(icon: s.icon, color: s.color, size: 46, label: s.label, onTap: () => onSense(s)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A bubble turned into a little text box, with the keyboard up.
class _EditBubble extends StatelessWidget {
  const _EditBubble({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.onDone,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 90, maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color, width: 3.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)],
      ),
      child: IntrinsicWidth(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onDone(),
          cursorColor: color,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Gj.edge(color), height: 1.3),
          decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: 'type...'),
        ),
      ),
    );
  }
}

/// "Say it in Bengali / Hindi": a word in either, back in English.
class _BridgeButtons extends StatelessWidget {
  const _BridgeButtons({required this.enabled, required this.onTap});
  final bool enabled;
  final void Function(HomeLanguage) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, lang) in HomeLanguage.values.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: enabled
                  ? () {
                      App.of(context).sounds.play(Sfx.pop);
                      onTap(lang);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Gj.teal.withValues(alpha: enabled ? 0.12 : 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: enabled ? Gj.teal : Gj.inkSoft, width: 2.5),
                ),
                child: Column(
                  children: [
                    Text(
                      '${lang.native} → English',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Gj.teal, height: 1.2),
                    ),
                    Text(
                      'Say it in ${lang.name}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Gj.inkSoft, height: 1.1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
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
