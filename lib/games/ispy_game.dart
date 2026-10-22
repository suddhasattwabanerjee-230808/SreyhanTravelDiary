import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import '../screens/moment_screen.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../vision.dart';
import '../widgets/playful.dart';
import 'game_kit.dart';
import 'game_logic.dart';

/// Travel I-Spy: a bingo card of nine things to find each day. When a photo
/// shows one (an animal, a bird, water, a ride...), its square is stamped with
/// that photo. A full row, column or diagonal is a BINGO.
class ISpyGame extends StatefulWidget {
  const ISpyGame({super.key});

  @override
  State<ISpyGame> createState() => _ISpyGameState();
}

class _ISpyGameState extends State<ISpyGame> {
  static const _color = Gj.lilac;
  List<DiaryDay>? _days;
  int _index = 0;
  int _celebrated = 0;

  App get _app => App.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_days == null) _load();
  }

  /// Today first (even if empty), then earlier days.
  Future<void> _load() async {
    final today = dateKey(_app.now());
    final days = await _app.store.allDays();
    if (!mounted) return;
    setState(() => _days = [if (days.isEmpty || days.first.date != today) DiaryDay(date: today), ...days]);
    _celebrate();
  }

  void _celebrate() {
    final lines = bingoLines(spyFinds(_days![_index]).keys.toSet());
    if (_index == 0 && lines > _celebrated) {
      _celebrated = lines;
      _app.sounds.play(Sfx.dhol);
      ConfettiBurst.show(context);
    }
  }

  Future<void> _addPicture() async {
    await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const MomentScreen()));
    if (!mounted) return;
    setState(() => _index = 0);
    await _load();
  }

  void _go(int delta) {
    _app.sounds.play(Sfx.whoosh);
    setState(() => _index += delta);
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    if (days == null) return const GameShell(title: 'Travel I-Spy', color: _color, sheruSays: '...', child: SizedBox());
    final day = days[_index];
    final found = spyFinds(day);
    final lines = bingoLines(found.keys.toSet());
    final isToday = _index == 0;
    final say = lines > 0
        ? 'BINGO! You found ${found.length} things and made $lines ${lines == 1 ? 'line' : 'lines'}!'
        : found.isEmpty
        ? (isToday ? 'Can you find these today? Take photos of them!' : 'Nothing found that day.')
        : 'You found ${found.length}! Get three in a row for BINGO!';
    return GameShell(
      title: 'Travel I-Spy',
      color: _color,
      sheruSays: say,
      happy: lines > 0,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              BlobButton(
                icon: Icons.chevron_left_rounded,
                color: _color,
                size: 46,
                onTap: _index < days.length - 1 ? () => _go(1) : null,
              ),
              Expanded(
                child: Center(
                  child: OutlinedTitle(isToday ? 'Today' : shortDate(day.day), size: 24, color: Gj.edge(_color), stroke: 5),
                ),
              ),
              BlobButton(icon: Icons.chevron_right_rounded, color: _color, size: 46, onTap: _index > 0 ? () => _go(-1) : null),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [for (final t in spyCard) _Square(thing: t, found: found[t])],
          ),
          if (isToday) ...[
            const SizedBox(height: 20),
            KutchButton(label: 'Add a picture', icon: Icons.add_a_photo_rounded, onTap: _addPicture),
          ],
        ],
      ),
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({required this.thing, required this.found});
  final Thing thing;
  final Moment? found;

  @override
  Widget build(BuildContext context) {
    final info = things[thing]!;
    final m = found;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: m != null ? Gj.leaf : info.color.withValues(alpha: 0.5), width: m != null ? 4 : 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (m != null) DiaryPhoto(m.photo, radius: 0),
          if (m == null)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(info.icon, color: info.color, size: 38),
                const SizedBox(height: 4),
                Text(
                  info.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Gj.edge(info.color), height: 1.05),
                ),
              ],
            ),
          if (m != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Gj.leaf.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        info.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
