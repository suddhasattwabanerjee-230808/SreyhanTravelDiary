import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../diary_store.dart';
import '../models.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../voice.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';
import '../widgets/mic_button.dart';
import '../words.dart';

/// Sheru's questions, one after another, to help the child say more.
/// (The AI coach replaces these with questions about the actual photo.)
const offlinePrompts = [
  'What is in your photo?',
  'Where were you?',
  'What colours can you see?',
  'Who was with you?',
  'How did you feel? Why?',
  'What could you hear?',
  'What was the best part?',
];

/// Add a moment: pick a photo, then talk about it. No keyboard anywhere.
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

  var _words = <String>[];
  String _live = '';
  bool _listening = false;
  bool _busy = false;
  double _level = 0;
  int? _selected;
  int? _replacing;
  int _prompt = 0;
  String? _sheruSays;
  bool _celebrating = false;
  VoiceReady _voiceReady = VoiceReady.ready;

  App get _app => App.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVoice());
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
    if (_replacing != null) return 'Say the new word!';
    if (_words.isEmpty) return offlinePrompts[0];
    return offlinePrompts[_prompt % offlinePrompts.length];
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
    });
  }

  // --- Talking ----------------------------------------------------------------

  void _tapMic() => _listening ? _stopTalking() : _startTalking();

  /// Listens until the mic is tapped again. When fixing a word, it stops by
  /// itself once the new word is heard.
  Future<void> _startTalking() async {
    if (_listening || _busy) return;
    setState(() {
      _listening = true;
      _live = '';
      _sheruSays = null;
    });
    await _app.sounds.hush();
    await _app.sounds.play(Sfx.listenOn);
    // Let the chime finish so it isn't heard as a word.
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted || !_listening) return;
    final ok = await _app.voice.start(
      onText: (t) {
        if (mounted) setState(() => _live = t);
      },
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
      oneShot: _replacing != null,
      onEnded: _stopTalking,
    );
    if (!ok && mounted) {
      setState(() {
        _listening = false;
        _sheruSays = "Oh no, I can't hear right now. Ask a grown-up to help!";
      });
      await _app.sounds.unhush();
      unawaited(_checkVoice());
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
      if (said.isEmpty) {
        _replacing = null;
        _sheruSays = "I didn't hear anything. Tap the mic and talk!";
      } else if (_replacing != null) {
        _words = replaceWord(_words, _replacing!, said);
        _replacing = null;
        _selected = null;
        _sheruSays = 'Fixed it!';
      } else {
        _words = [..._words, ...splitWords(said)];
        _prompt++;
        _sheruSays = null;
      }
    });
    _app.sounds.play(said.isEmpty ? Sfx.oops : Sfx.sparkle);
  }

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
    setState(() {
      _replacing = _selected;
      _sheruSays = null;
    });
    _startTalking();
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
      _prompt = 0;
      _sheruSays = "Let's start again!";
    });
  }

  // --- Saving -----------------------------------------------------------------

  Future<void> _save() async {
    if (_words.isEmpty || _photo == null || _busy) return;
    setState(() => _busy = true);
    final store = _app.store;
    final now = _app.now();
    final photo = await store.importPhoto(_photo!, _id);
    await store.addMoment(
      Moment(
        id: _id,
        createdAt: now,
        photo: photo,
        text: tidySentence(joinWords(_words)),
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
        if (didPop) return;
        if (_listening) await _app.voice.cancel();
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        body: BandhaniBackground(
          child: SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(child: _photo == null ? _choosePhoto() : _talkAboutIt()),
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

  Widget _talkAboutIt() {
    final live = splitWords(_live);
    final canTalk = _voiceReady == VoiceReady.ready && !_celebrating;
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            // Room at the bottom so nothing hides under the floating mic.
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 220),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.34),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Polaroid(image: FileImage(File(_photo!)), tilt: -0.03),
                      ),
                    ),
                    if (!_listening && !_celebrating)
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
                ),
                const SizedBox(height: 18),
                SheruSays(_message, size: 84, listening: _listening, level: _level, happy: _celebrating),
                const SizedBox(height: 12),
                _wordBoard(live),
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
              child: _fixingWord ? _wordActions(canTalk) : _talkDock(canTalk),
            ),
          ),
        ),
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
            onTap: _words.isEmpty || _listening || _busy ? null : _save,
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

  Widget _side(Widget child) => Padding(padding: const EdgeInsets.only(bottom: 34), child: child);

  Widget _wordBoard(List<String> live) {
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
                  if (_replacing == null)
                    for (var i = 0; i < live.length; i++)
                      WordBubble(word: live[i], color: Gj.festive[(_words.length + i) % Gj.festive.length], live: true),
                  if (_replacing != null && live.isNotEmpty)
                    WordBubble(word: live.join(' '), color: Gj.kumkum, live: true),
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
