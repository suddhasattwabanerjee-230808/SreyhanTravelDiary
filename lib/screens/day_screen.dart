import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../diary_store.dart';
import '../feelings.dart';
import '../models.dart';
import '../places.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import '../widgets/sentence_view.dart';
import '../widgets/sheru.dart';
import '../widgets/stamp.dart';
import 'home_screen.dart' show childName;
import 'export_screen.dart';
import 'moment_screen.dart';

/// One diary day as a scrapbook: each moment a taped-in photo with the
/// child's words underneath. "Read me my day" has Sheru read every page
/// aloud, turning to each in turn.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.date});
  final String date;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  DiaryDay? _day;
  DiaryStore? _store;

  // Reading aloud: which moment, which word, and whether the whole day is
  // being read.
  int? _readingAt;
  (int, int)? _span;
  bool _replaying = false;
  final _keys = <String, GlobalKey>{};

  App get _app => App.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = _app.store;
    if (store != _store) {
      _store?.removeListener(_load);
      _store = store..addListener(_load);
      _load();
    }
  }

  @override
  void deactivate() {
    if (_readingAt != null) {
      _replaying = false;
      _app.speaker.stop();
      _app.sounds.unhush();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _store?.removeListener(_load);
    super.dispose();
  }

  /// Turns to moment [i] and reads it, lighting up each word.
  Future<void> _read(int i) async {
    final m = _day!.moments[i];
    setState(() {
      _readingAt = i;
      _span = null;
    });
    final ctx = _keys[m.id]?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx, alignment: 0.12, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    }
    if (!mounted) return;
    await _app.speaker.say(
      m.text,
      onWord: (start, end) {
        if (mounted && _readingAt == i) setState(() => _span = (start, end));
      },
    );
  }

  Future<void> _hear(int i) async {
    if (_readingAt != null) return;
    await _app.sounds.hush();
    await _read(i);
    await _app.sounds.unhush();
    if (mounted) setState(() => _readingAt = null);
  }

  /// Bedtime replay: the whole day, page by page. Tap again to stop.
  Future<void> _readDay() async {
    if (_replaying) {
      _replaying = false;
      await _app.speaker.stop();
      return;
    }
    final day = _day;
    if (day == null || day.isEmpty || _readingAt != null) return;
    setState(() {
      _replaying = true;
      _readingAt = 0;
    });
    await _app.sounds.hush();
    await _app.speaker.say(_isToday ? 'Here is your day today!' : 'Here is your day. ${prettyDate(day.day)}.');
    for (var i = 0; i < day.moments.length && _replaying && mounted; i++) {
      if (i > 0) _app.sounds.play(Sfx.whoosh);
      await _read(i);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (_replaying && mounted) {
      _app.sounds.play(Sfx.sparkle);
      await _app.speaker.say('The end! Well done, $childName.');
    }
    await _app.sounds.unhush();
    if (mounted) {
      setState(() {
        _replaying = false;
        _readingAt = null;
      });
    }
  }

  Future<void> _load() async {
    final d = await _store!.day(widget.date);
    if (mounted) setState(() => _day = d);
  }

  bool get _isToday => widget.date == dateKey(_app.now());

  /// Long press on a page: change the words, or throw the page away.
  Future<void> _options(Moment m) async {
    if (_readingAt != null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Gj.sand,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Gj.peacock, size: 32),
                title: const Text('Change the words', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Gj.kumkum, size: 32),
                title: const Text('Throw this page away', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'edit') await _edit(m);
    if (choice == 'delete') await _delete(m);
  }

  Future<void> _edit(Moment m) async {
    final controller = TextEditingController(text: m.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Gj.sand,
        title: const Text('Change the words'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 22),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || text == m.text) return;
    _app.sounds.play(Sfx.pop);
    await _app.store.editMomentText(widget.date, m.id, text, _app.now());
  }

  Future<void> _delete(Moment m) async {
    if (!await askYesNo(context, 'Throw this page away?')) return;
    _app.sounds.play(Sfx.whoosh);
    await _app.store.deleteMoment(widget.date, m.id);
  }

  Future<void> _add() async {
    await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const MomentScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    return Scaffold(
      body: BandhaniBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    BlobButton(
                      icon: Icons.arrow_back_rounded,
                      color: Gj.peacock,
                      size: 56,
                      sound: Sfx.whoosh,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: OutlinedTitle(
                            _isToday ? 'My day today' : prettyDate(DateTime.parse(widget.date)),
                            size: _isToday ? 30 : 24,
                          ),
                        ),
                      ),
                    ),
                    BlobButton(
                      icon: _replaying ? Icons.stop_rounded : Icons.bedtime_rounded,
                      color: Gj.lilac,
                      size: 52,
                      onTap: day == null || day.isEmpty || (_readingAt != null && !_replaying) ? null : _readDay,
                    ),
                    const SizedBox(width: 6),
                    // Share my day: a storybook, postcard or comic.
                    BlobButton(
                      icon: Icons.share_rounded,
                      color: Gj.leaf,
                      size: 52,
                      onTap: day == null || day.isEmpty
                          ? null
                          : () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute<void>(builder: (_) => ExportScreen(date: widget.date))),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: day == null
                    ? const SizedBox()
                    : day.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: SheruSays('No pictures yet. Let\'s add one!', size: 110),
                        ),
                      )
                    // Every page built at once, so reading aloud can turn to any of them.
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(30, 12, 30, 24),
                        child: Column(
                          children: [
                            _DayPlaces(day: day, onTap: (p) => _app.speaker.say('${p.name}! ${p.fact}')),
                            for (final (i, m) in day.moments.indexed)
                              Padding(
                                key: _keys.putIfAbsent(m.id, GlobalKey.new),
                                padding: const EdgeInsets.only(top: 12, bottom: 22),
                                child: _MomentPage(
                                  moment: m,
                                  index: i,
                                  speaking: _readingAt == i ? (_span ?? (0, 0)) : null,
                                  onHear: _readingAt == null ? () => _hear(i) : null,
                                  onLongPress: () => _options(m),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              if (_isToday)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: KutchButton(label: 'Add a picture', icon: Icons.add_a_photo_rounded, onTap: _add),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The places this day's photos were taken, as pins to tap for their fact.
class _DayPlaces extends StatelessWidget {
  const _DayPlaces({required this.day, required this.onTap});
  final DiaryDay day;
  final void Function(Place) onTap;

  @override
  Widget build(BuildContext context) {
    final places = {for (final m in day.moments) ?placeById(m.place)};
    if (places.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [for (final p in places) PlacePill(p, onTap: () => onTap(p))],
      ),
    );
  }
}

class _MomentPage extends StatelessWidget {
  const _MomentPage({
    required this.moment,
    required this.index,
    required this.speaking,
    required this.onHear,
    required this.onLongPress,
  });

  final Moment moment;
  final int index;

  /// The word being read aloud, if this page is.
  final (int, int)? speaking;
  final VoidCallback? onHear;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final m = moment;
    final tilt = index.isEven ? -0.025 : 0.03;
    final time = TimeOfDay.fromDateTime(m.createdAt).format(context);
    final feeling = Feeling.byName(m.feeling);
    final place = placeById(m.place);
    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: speaking != null ? 1.03 : 1,
        duration: const Duration(milliseconds: 300),
        child: Polaroid(
          image: FileImage(app.store.file(m.photo)),
          tilt: tilt,
          tapeColor: Gj.festive[index % Gj.festive.length],
          caption: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SentenceView(text: m.text, learned: m.learned, speaking: speaking, size: 22)),
                  const SizedBox(width: 8),
                  BlobButton(icon: Icons.volume_up_rounded, color: Gj.teal, size: 50, onTap: onHear),
                ],
              ),
              if (m.learned.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final w in m.learned) LearnedWordChip(word: w, onTap: () => app.speaker.say(w.word)),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(time, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Gj.inkSoft)),
                  if (place != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '· ${place.name}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Gj.edge(place.color)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (feeling != null)
                    Tooltip(
                      message: 'I felt ${feeling.word}',
                      child: GestureDetector(
                        onTap: () => app.speaker.say('I felt ${feeling.word}!'),
                        child: FeelingFace(feeling, size: 40),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
