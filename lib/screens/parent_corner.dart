import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../app_channel.dart';
import '../app_scope.dart';
import '../backup.dart';
import '../models.dart';
import '../places.dart';
import '../sound_board.dart';
import '../stats.dart';
import '../theme.dart';
import '../updates.dart';
import 'how_to_screen.dart';
import 'word_jar_screen.dart' show collectWords;

/// The way into the grown-ups' corner: a small lock to hold for three
/// seconds, then a sum to answer. Children can tap it all they like.
class GrownUpsLock extends StatefulWidget {
  const GrownUpsLock({super.key, this.size = 40});
  final double size;

  @override
  State<GrownUpsLock> createState() => _GrownUpsLockState();
}

class _GrownUpsLockState extends State<GrownUpsLock> with SingleTickerProviderStateMixin {
  late final _hold = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _open();
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    _hold.value = 0;
    final ok = await showDialog<bool>(context: context, builder: (_) => const _SumDialog());
    if (ok == true && mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ParentCorner()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: true,
      label: 'Grown-ups: hold for 3 seconds',
      child: Listener(
        onPointerDown: (_) => _hold.forward(),
        onPointerUp: (_) => _hold.isCompleted ? null : _hold.reverse(),
        onPointerCancel: (_) => _hold.reverse(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => SizedBox.square(
            dimension: s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle),
                ),
                if (_hold.value > 0)
                  SizedBox.square(
                    dimension: s,
                    child: CircularProgressIndicator(value: _hold.value, strokeWidth: 4, color: Gj.maroon),
                  ),
                Icon(Icons.lock_rounded, color: Gj.inkSoft.withValues(alpha: 0.8), size: s * 0.5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "What is 7 + 6?" with four big answers. Easy for a grown-up, a small
/// wall for a young child.
class _SumDialog extends StatefulWidget {
  const _SumDialog();

  @override
  State<_SumDialog> createState() => _SumDialogState();
}

class _SumDialogState extends State<_SumDialog> {
  final _rnd = Random();
  late int _a, _b;
  late List<int> _answers;

  @override
  void initState() {
    super.initState();
    _a = 12 + _rnd.nextInt(30);
    _b = 6 + _rnd.nextInt(20);
    final right = _a + _b;
    final set = {right};
    while (set.length < 4) {
      set.add(right + (_rnd.nextBool() ? 1 : -1) * (1 + _rnd.nextInt(9)));
    }
    _answers = set.toList()..shuffle(_rnd);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Gj.sand,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('For grown-ups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Gj.inkSoft)),
            Text('$_a + $_b = ?', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Gj.ink)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final n in _answers)
                  SizedBox(
                    width: 104,
                    height: 60,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Gj.peacock,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => Navigator.of(context).pop(n == _a + _b),
                      child: Text('$n', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}

/// The grown-ups' corner: music and sounds, updates, how the child's English
/// is growing, a backup of the whole diary, and deleting a day.
class ParentCorner extends StatefulWidget {
  const ParentCorner({super.key});

  @override
  State<ParentCorner> createState() => _ParentCornerState();
}

class _ParentCornerState extends State<ParentCorner> {
  List<DiaryDay>? _days;
  String? _version;
  String? _busy;

  App get _app => App.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_days == null) {
      _load();
      PackageInfo.fromPlatform()
          .timeout(const Duration(seconds: 3))
          .then((i) => mounted ? setState(() => _version = '${i.version} (${i.buildNumber})') : null, onError: (_) {});
    }
  }

  Future<void> _load() async {
    final days = await _app.store.allDays();
    if (mounted) setState(() => _days = days);
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _backup() async {
    setState(() => _busy = 'Packing the diary...');
    try {
      await Backup.share(_app.store, date: dateKey(_app.now()));
    } catch (e, st) {
      reportError('Backup: $e', st);
      _say("The backup didn't work: $e");
    }
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _restore() async {
    setState(() => _busy = 'Adding the backup...');
    try {
      final added = await Backup.restore(_app.store);
      if (added != null) {
        _say(added == 0 ? 'Nothing new: every picture in that backup is already here.' : 'Added $added ${added == 1 ? 'picture' : 'pictures'} from the backup.');
        await _load();
      }
    } catch (e, st) {
      reportError('Restore: $e', st);
      _say("That backup couldn't be read: $e");
    }
    if (mounted) setState(() => _busy = null);
  }

  /// A song from the phone for the music, copied into the app (DiaryFiles.kt).
  Future<void> _pickSong() async {
    try {
      final dir = '${(await getApplicationDocumentsDirectory()).path}/music';
      final song = await const MethodChannel('sreyhan/files').invokeMapMethod<String, String>('pickSong', {'dir': dir});
      if (song == null || !mounted) return;
      await _app.sounds.setOwnSong(song['path']!, song['name']!);
      _say('Now playing "${song['name']}".');
    } catch (e, st) {
      reportError('Picking a song: $e', st);
      _say("That song couldn't be used: $e");
    }
  }

  Future<void> _deleteDay(DiaryDay d) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${prettyDate(d.day)}?'),
        content: Text('Its ${d.moments.length} ${d.moments.length == 1 ? 'picture' : 'pictures'} and words will be gone for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Gj.kumkum),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _app.store.deleteDay(d.date);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final sounds = _app.sounds;
    return Scaffold(
      backgroundColor: Gj.salt,
      appBar: AppBar(
        backgroundColor: Gj.salt,
        title: const Text("Grown-ups' corner", style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: days == null
          ? const SizedBox()
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    const _Section('Music and sounds'),
                    _Card(
                      child: ListenableBuilder(
                        listenable: sounds,
                        builder: (context, _) => Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Music'),
                              subtitle: const Text('Plays on the home screen; the child can pick it with the music button'),
                              value: sounds.musicOn,
                              onChanged: sounds.setMusicOn,
                            ),
                            RadioGroup<MusicTrack>(
                              groupValue: sounds.musicOn ? sounds.track : null,
                              onChanged: (t) => t == null ? null : sounds.setTrack(t),
                              child: Column(
                                children: [
                                  for (final t in sounds.tracks)
                                    RadioListTile<MusicTrack>(
                                      value: t,
                                      dense: true,
                                      title: Text(t == MusicTrack.own ? 'My own song: ${sounds.ownSongName ?? ''}' : t.label),
                                    ),
                                ],
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.library_music_rounded, color: Gj.lilac),
                              title: Text(sounds.ownSong == null ? 'Pick a song from this phone' : 'Pick a different song'),
                              subtitle: const Text('Any music file you have, e.g. a soundtrack you bought. It stays on this phone.'),
                              onTap: _pickSong,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('Sound effects'),
                              subtitle: const Text('Pops, chimes and the dhol'),
                              value: sounds.sfxOn,
                              onChanged: sounds.setSfxOn,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const _Section('Updates'),
                    _Card(child: _UpdateTile(version: _version)),
                    const _Section('Progress'),
                    _Progress(days: days),
                    const _Section('Keep the diary safe'),
                    _Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.backup_rounded, color: Gj.peacock),
                            title: const Text('Save a backup'),
                            subtitle: const Text('Every day and photo in one .zip file. Send it to Drive or keep it on a computer.'),
                            onTap: _busy == null && days.isNotEmpty ? _backup : null,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.settings_backup_restore_rounded, color: Gj.leaf),
                            title: const Text('Add a backup to this phone'),
                            subtitle: const Text('Pick a backup .zip. Its days are added; nothing here is replaced.'),
                            onTap: _busy == null ? _restore : null,
                          ),
                        ],
                      ),
                    ),
                    if (days.isNotEmpty) ...[
                      const _Section('Delete a day'),
                      _Card(
                        child: Column(
                          children: [
                            for (final d in days)
                              ListTile(
                                title: Text(prettyDate(d.day)),
                                subtitle: Text('${d.moments.length} ${d.moments.length == 1 ? 'picture' : 'pictures'}'),
                                trailing: IconButton(
                                  tooltip: 'Delete this day',
                                  icon: const Icon(Icons.delete_outline_rounded, color: Gj.kumkum),
                                  onPressed: () => _deleteDay(d),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const _Section('Help'),
                    _Card(
                      child: ListTile(
                        leading: const Icon(Icons.menu_book_rounded, color: Gj.lilac),
                        title: const Text('How to Use'),
                        subtitle: const Text('The picture guide Sheru reads aloud'),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HowToScreen())),
                      ),
                    ),
                    if (_version != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(child: Text('Version $_version', style: const TextStyle(color: Gj.inkSoft))),
                      ),
                  ],
                ),
                if (_busy != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0x66000000),
                      child: Center(
                        child: _Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [const CircularProgressIndicator(), const SizedBox(width: 16), Text(_busy!)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Gj.ink)),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    elevation: 0.5,
    child: child,
  );
}

/// Headline numbers, then one small chart per measure, a bar per day.
class _Progress extends StatelessWidget {
  const _Progress({required this.days});
  final List<DiaryDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const _Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Charts appear once the diary has a day in it.')));
    }
    final stats = dayStats(days);
    final pictures = stats.fold(0, (n, s) => n + s.pictures);
    final words = stats.fold(0, (n, s) => n + s.words);
    final describing = stats.fold(0, (n, s) => n + s.describing);
    final stamps = passportStamps([
      for (final d in days)
        for (final m in d.moments) ?m.place,
    ]).length;
    final recent = stats.length > 10 ? stats.sublist(stats.length - 10) : stats;
    String label(DayStats s) => shortDate(DateTime.parse(s.date));
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.25,
          children: [
            _Tile('${stats.length}', 'diary days'),
            _Tile('$pictures', 'pictures'),
            _Tile('$words', 'words said'),
            _Tile((words / max(pictures, 1)).toStringAsFixed(1), 'words per picture'),
            _Tile('$describing', 'describing words'),
            _Tile('${collectWords(days).length}', 'Word Jar words'),
          ],
        ),
        if (stamps > 0) ...[
          const SizedBox(height: 8),
          _Card(
            child: ListTile(
              leading: const Icon(Icons.public_rounded, color: Gj.teal),
              title: Text('$stamps passport ${stamps == 1 ? 'stamp' : 'stamps'}'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _BarChart(
          title: 'Words per picture',
          subtitle: 'How long each day\'s sentences are',
          bars: [for (final s in recent) (label(s), s.sentenceLength)],
          decimals: 1,
        ),
        const SizedBox(height: 12),
        _BarChart(
          title: 'Describing words',
          subtitle: 'Colours, sizes, feelings, tastes... per day',
          bars: [for (final s in recent) (label(s), s.describing.toDouble())],
        ),
        const SizedBox(height: 12),
        _BarChart(
          title: 'New words',
          subtitle: 'English words found from Bengali or Hindi, per day',
          bars: [for (final s in recent) (label(s), s.newWords.toDouble())],
        ),
        if (stats.length > recent.length)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Charts show the last 10 diary days.', style: TextStyle(color: Gj.inkSoft)),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Gj.ink, height: 1.1)),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Gj.inkSoft, height: 1.1),
          ),
        ],
      ),
    ),
  );
}

/// One measure over the days: a thin bar per day, one colour, on a quiet
/// axis. Tap a bar to read its value; the latest day's is shown to start.
class _BarChart extends StatefulWidget {
  const _BarChart({required this.title, required this.subtitle, required this.bars, this.decimals = 0});
  final String title, subtitle;
  final List<(String, double)> bars;
  final int decimals;

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    final picked = (_picked ?? bars.length - 1).clamp(0, bars.length - 1);
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Gj.ink)),
            Text(widget.subtitle, style: const TextStyle(fontSize: 13, color: Gj.inkSoft)),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final i = _BarPainter.indexAt(d.localPosition.dx, box.maxWidth, bars.length);
                    setState(() => _picked = i);
                  },
                  child: CustomPaint(
                    size: Size(box.maxWidth, 150),
                    painter: _BarPainter(bars, picked, widget.decimals),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.bars, this.picked, this.decimals);
  final List<(String, double)> bars;
  final int picked;
  final int decimals;

  static const _left = 30.0, _bottom = 22.0, _top = 22.0;
  static const _bar = Gj.peacock;
  static const _barSoft = Color(0xFF9CC7E3);

  static int indexAt(double x, double width, int n) => ((x - _left) / ((width - _left) / n)).floor().clamp(0, n - 1);

  TextPainter _text(String s, {Color color = Gj.inkSoft, double size = 11, FontWeight weight = FontWeight.w600}) =>
      TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontFamily: fontFamily, fontSize: size, color: color, fontWeight: weight)),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final plotH = size.height - _bottom - _top;
    final top = bars.fold(0.0, (m, b) => max(m, b.$2));
    // A rounded axis top: 1, 2, 5, 10... so the gridlines get plain numbers.
    final step = [1, 2, 5, 10, 20, 50, 100].map((e) => e.toDouble()).firstWhere((s) => s * 3 >= top, orElse: () => (top / 3).ceilToDouble());
    final axisMax = step * 3;
    final grid = Paint()
      ..color = const Color(0xFFE6E2F0)
      ..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final y = _top + plotH - plotH * g / 3;
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      final t = _text((step * g).toStringAsFixed(0));
      t.paint(canvas, Offset(_left - t.width - 6, y - t.height / 2));
    }
    final slot = (size.width - _left) / bars.length;
    final w = min(slot * 0.6, 22.0);
    for (final (i, (label, v)) in bars.indexed) {
      final cx = _left + slot * (i + 0.5);
      final h = axisMax == 0 ? 0.0 : plotH * v / axisMax;
      final base = _top + plotH;
      if (h > 0) {
        final r = Radius.circular(min(4, w / 2));
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(cx - w / 2, base - h, w, h), topLeft: r, topRight: r),
          Paint()..color = i == picked ? _bar : _barSoft,
        );
      }
      // Day labels: every one if they fit, otherwise every other.
      if (bars.length <= 6 || i.isEven == (bars.length - 1).isEven) {
        final t = _text(label, size: 10, color: i == picked ? Gj.ink : Gj.inkSoft);
        t.paint(canvas, Offset(cx - t.width / 2, base + 5));
      }
      if (i == picked) {
        final t = _text(v.toStringAsFixed(decimals), color: Gj.ink, size: 13, weight: FontWeight.w800);
        t.paint(canvas, Offset((cx - t.width / 2).clamp(_left, size.width - t.width), base - h - t.height - 3));
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.bars != bars || old.picked != picked;
}

/// "Check for updates": asks GitHub now, then offers the new version, with
/// the download's progress in place.
class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.version});
  final String? version;

  @override
  Widget build(BuildContext context) {
    final updates = Updates.instance;
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final latest = updates.latest;
        final progress = updates.progress;
        final String title, subtitle;
        VoidCallback? onTap = updates.check;
        var icon = Icons.system_update_rounded;
        if (progress != null) {
          title = updates.installing ? 'Installing...' : 'Downloading the update...';
          subtitle = '${(progress * 100).round()}%';
          onTap = null;
        } else if (updates.checking) {
          title = 'Checking...';
          subtitle = 'Asking GitHub for the newest version';
          onTap = null;
        } else if (latest != null) {
          title = 'Install version ${latest.versionName}';
          subtitle = updates.error != null ? "Couldn't update: ${updates.error}. Tap to try again." : 'Tap to download and install. The diary is kept.';
          onTap = updates.install;
          icon = Icons.download_rounded;
        } else if (updates.lastCheckOk == false) {
          title = 'Check for updates';
          subtitle = "Couldn't reach GitHub. Is the internet on?";
        } else if (updates.lastCheckOk == true) {
          title = 'Check for updates';
          subtitle = 'This is the newest version${version == null ? '' : ' ($version)'}.';
          icon = Icons.verified_rounded;
        } else {
          title = 'Check for updates';
          subtitle = version == null ? 'See if a new version is out' : 'This phone has $version';
        }
        return ListTile(
          leading: progress != null
              ? SizedBox.square(dimension: 24, child: CircularProgressIndicator(value: progress, strokeWidth: 3))
              : Icon(icon, color: latest != null ? Gj.leaf : Gj.peacock),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: onTap,
        );
      },
    );
  }
}
