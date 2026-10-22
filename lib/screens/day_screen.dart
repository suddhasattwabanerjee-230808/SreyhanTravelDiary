import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../diary_store.dart';
import '../models.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';
import 'moment_screen.dart';

/// One diary day as a scrapbook: each moment a taped-in photo with the
/// child's words underneath.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.date});
  final String date;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  DiaryDay? _day;
  DiaryStore? _store;

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
  void dispose() {
    _store?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final d = await _store!.day(widget.date);
    if (mounted) setState(() => _day = d);
  }

  bool get _isToday => widget.date == dateKey(_app.now());

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
                      child: Center(
                        child: OutlinedTitle(
                          _isToday ? 'My day today' : prettyDate(DateTime.parse(widget.date)),
                          size: _isToday ? 30 : 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 56),
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
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(30, 20, 30, 24),
                        itemCount: day.moments.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 34),
                          child: _MomentPage(
                            moment: day.moments[i],
                            index: i,
                            onLongPress: () => _delete(day.moments[i]),
                          ),
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

class _MomentPage extends StatelessWidget {
  const _MomentPage({required this.moment, required this.index, required this.onLongPress});

  final Moment moment;
  final int index;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final store = App.of(context).store;
    final tilt = index.isEven ? -0.025 : 0.03;
    final time = TimeOfDay.fromDateTime(moment.createdAt).format(context);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Polaroid(
        image: FileImage(store.file(moment.photo)),
        tilt: tilt,
        tapeColor: Gj.festive[index % Gj.festive.length],
        caption: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              moment.text,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2, color: Gj.ink),
            ),
            Text(time, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Gj.inkSoft)),
          ],
        ),
      ),
    );
  }
}
