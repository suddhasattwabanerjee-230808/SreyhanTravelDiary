import 'package:flutter/material.dart';

import '../theme.dart';
import '../updates.dart';
import 'playful.dart';

/// "A new version is ready!" on the home screen, with the download's progress
/// in place once it's tapped. Hidden when there's nothing new.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = Updates.instance;
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final latest = updates.latest;
        if (latest == null) return const SizedBox.shrink();
        final progress = updates.progress;
        final String title;
        final String subtitle;
        if (progress != null) {
          title = updates.installing ? 'Installing...' : 'Getting the new diary...';
          subtitle = '${(progress * 100).round()}%';
        } else if (updates.error != null) {
          title = "Couldn't update";
          subtitle = 'Tap to try again';
        } else {
          title = 'New diary update!';
          subtitle = 'Version ${latest.versionName} is ready';
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GestureDetector(
            onTap: progress == null ? updates.install : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Gj.leaf, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, color: Gj.leaf, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Gj.ink, height: 1.1)),
                        Text(subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Gj.inkSoft)),
                        if (progress != null) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              color: Gj.leaf,
                              backgroundColor: Gj.leaf.withValues(alpha: 0.18),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (progress == null) ...[
                    const SizedBox(width: 8),
                    BlobButton(icon: Icons.download_rounded, color: Gj.leaf, size: 52, onTap: updates.install),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
