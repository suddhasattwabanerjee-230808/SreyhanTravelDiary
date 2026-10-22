import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../sound_board.dart';
import '../theme.dart';

const _icons = {
  MusicTrack.garba: Icons.celebration_rounded,
  MusicTrack.blocks: Icons.view_in_ar_rounded,
  MusicTrack.obby: Icons.sports_score_rounded,
  MusicTrack.own: Icons.library_music_rounded,
};

const _colors = {
  MusicTrack.garba: Gj.kumkum,
  MusicTrack.blocks: Gj.leaf,
  MusicTrack.obby: Gj.peacock,
  MusicTrack.own: Gj.lilac,
};

/// Pick the music, or switch it off: big buttons, one per song.
Future<void> showMusicSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Gj.sand,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
  builder: (_) => const _MusicSheet(),
);

class _MusicSheet extends StatelessWidget {
  const _MusicSheet();

  @override
  Widget build(BuildContext context) {
    final sounds = App.of(context).sounds;
    return ListenableBuilder(
      listenable: sounds,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OutlinedTitle('Music', size: 30),
              const SizedBox(height: 10),
              for (final t in sounds.tracks)
                _Choice(
                  icon: _icons[t]!,
                  color: _colors[t]!,
                  label: t == MusicTrack.own ? (sounds.ownSongName ?? t.label) : t.label,
                  on: sounds.musicOn && sounds.track == t,
                  onTap: () => sounds.setTrack(t),
                ),
              _Choice(
                icon: Icons.music_off_rounded,
                color: Gj.inkSoft,
                label: 'No music',
                on: !sounds.musicOn,
                onTap: () => sounds.setMusicOn(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.color, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        child: GestureDetector(
          onTap: () {
            App.of(context).sounds.play(Sfx.pop);
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: on ? color : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color, width: 3),
              boxShadow: [BoxShadow(color: Gj.edge(color).withValues(alpha: 0.5), offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: on ? Colors.white : color, shape: BoxShape.circle),
                  child: Icon(icon, color: on ? color : Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: on ? Colors.white : Gj.edge(color)),
                  ),
                ),
                if (on) const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
