import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'sky.dart';

const _short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Yesterday", "3 days ago"...
String daysAgo(DateTime date, DateTime today) {
  final n = dayOnly(today).difference(dayOnly(date)).inDays;
  return switch (n) { 0 => 'Today', 1 => 'Yesterday', _ => '$n days ago' };
}

/// Which day a photo belongs to, as kites: Today is first, then each day
/// before it. The last kite opens every older day.
class KiteDateStrip extends StatelessWidget {
  const KiteDateStrip({super.key, required this.date, required this.today, required this.onChanged});

  final DateTime date, today;
  final ValueChanged<DateTime> onChanged;

  static const _recent = 7;

  @override
  Widget build(BuildContext context) {
    final t = dayOnly(today), picked = dayOnly(date);
    final olderPicked = t.difference(picked).inDays >= _recent;
    return Column(
      children: [
        Text(
          prettyDate(picked),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Gj.ink),
        ),
        Text(daysAgo(picked, t), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Gj.inkSoft)),
        const SizedBox(height: 4),
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (var i = 0; i < _recent; i++)
                _DayKite(
                  day: DateTime(t.year, t.month, t.day - i),
                  index: i,
                  selected: t.difference(picked).inDays == i,
                  label: i == 0 ? 'Today' : _short[DateTime(t.year, t.month, t.day - i).weekday - 1],
                  onTap: onChanged,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    FlyingKite(
                      width: 56,
                      color: Gj.lilac,
                      accent: Gj.marigold,
                      phase: 0.9,
                      glow: olderPicked,
                      onTap: () async {
                        final d = await pickKiteDate(context, initial: picked, today: t);
                        if (d != null) onChanged(d);
                      },
                      child: const Icon(Icons.history_rounded, color: Gj.lilac),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -22),
                      child: const Text('Older', style: TextStyle(fontWeight: FontWeight.w800, color: Gj.inkSoft)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayKite extends StatelessWidget {
  const _DayKite({
    required this.day,
    required this.index,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final DateTime day;
  final int index;
  final bool selected;
  final String label;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final c = Gj.festive[index % Gj.festive.length];
    final a = Gj.festive[(index + 5) % Gj.festive.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          FlyingKite(
            width: selected ? 66 : 52,
            color: c,
            accent: a,
            phase: index * 0.37,
            glow: selected,
            onTap: () => onTap(day),
            child: Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w800, color: c, height: 1.1)),
          ),
          Transform.translate(
            offset: Offset(0, selected ? -30 : -20),
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Gj.ink : Gj.inkSoft, fontSize: selected ? 17 : 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every day of a month as a kite with its weekday name, for choosing an old
/// day. Arrows move between months; days after today aren't there.
Future<DateTime?> pickKiteDate(BuildContext context, {required DateTime initial, required DateTime today}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Gj.sand,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _MonthKites(initial: dayOnly(initial), today: dayOnly(today)),
  );
}

class _MonthKites extends StatefulWidget {
  const _MonthKites({required this.initial, required this.today});
  final DateTime initial, today;

  @override
  State<_MonthKites> createState() => _MonthKitesState();
}

class _MonthKitesState extends State<_MonthKites> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  bool get _isThisMonth => _month.year == widget.today.year && _month.month == widget.today.month;

  void _move(int by) => setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final last = _isThisMonth ? widget.today.day : DateUtils.getDaysInMonth(_month.year, _month.month);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 14),
            const Text('Which day was it?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton.filled(
                    onPressed: () => _move(-1),
                    style: IconButton.styleFrom(backgroundColor: Gj.peacock),
                    icon: const Icon(Icons.chevron_left_rounded, size: 34),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Gj.peacock),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _isThisMonth ? null : () => _move(1),
                    style: IconButton.styleFrom(backgroundColor: Gj.peacock),
                    icon: const Icon(Icons.chevron_right_rounded, size: 34),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.62,
                ),
                itemCount: last,
                itemBuilder: (context, i) {
                  final day = DateTime(_month.year, _month.month, i + 1);
                  final selected = day == widget.initial;
                  final c = Gj.festive[(i + _month.month) % Gj.festive.length];
                  final a = Gj.festive[(i + _month.month + 5) % Gj.festive.length];
                  return Column(
                    children: [
                      FlyingKite(
                        width: 46,
                        color: c,
                        accent: a,
                        phase: i * 0.13,
                        glow: selected,
                        onTap: () => Navigator.of(context).pop(day),
                        child: Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w800, color: c, height: 1.1)),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -14),
                        child: Text(
                          _short[day.weekday - 1],
                          style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Gj.ink : Gj.inkSoft),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
