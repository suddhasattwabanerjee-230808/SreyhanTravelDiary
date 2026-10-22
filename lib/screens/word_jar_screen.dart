import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import '../sound_board.dart';
import '../theme.dart';
import '../widgets/playful.dart';
import '../widgets/sheru.dart';
import '../words.dart';

/// A word Sheru taught, with the photo it came from.
class JarWord {
  const JarWord(this.word, this.photo, this.date);
  final NewWord word;
  final String photo;
  final String date;
}

/// Every new word from every day, newest first, each word once.
List<JarWord> collectWords(List<DiaryDay> days) {
  final seen = <String>{};
  final out = <JarWord>[];
  for (final d in days) {
    for (final m in d.moments.reversed) {
      for (final w in m.newWords) {
        if (seen.add(bareWord(w.word))) out.add(JarWord(w, m.photo, d.date));
      }
    }
  }
  return out;
}

/// The Word Jar: a card for every word learned, with the child's own photo
/// behind it. Tap a card to hear it.
class WordJarScreen extends StatefulWidget {
  const WordJarScreen({super.key});

  @override
  State<WordJarScreen> createState() => _WordJarScreenState();
}

class _WordJarScreenState extends State<WordJarScreen> {
  List<JarWord>? _words;
  String? _saying;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_words == null) _load();
  }

  Future<void> _load() async {
    final days = await App.of(context).store.allDays();
    if (mounted) setState(() => _words = collectWords(days));
  }

  Future<void> _say(JarWord w) async {
    final app = App.of(context);
    app.sounds.play(Sfx.pop);
    setState(() => _saying = w.word.word);
    await app.sounds.hush();
    await app.speaker.say(w.word.meaning.isEmpty ? w.word.word : '${w.word.word}. ${w.word.meaning}');
    await app.sounds.unhush();
    if (mounted) setState(() => _saying = null);
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
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
                    const Expanded(child: Center(child: OutlinedTitle('My Word Jar', size: 30))),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              Expanded(
                child: words == null
                    ? const SizedBox()
                    : words.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: SheruSays('Make a Super Sentence, and new words will fill your jar!', size: 110),
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                              child: SheruSays(
                                'You know ${words.length} new ${words.length == 1 ? 'word' : 'words'}! Tap one to hear it.',
                                size: 80,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            sliver: SliverGrid.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.78,
                              ),
                              itemCount: words.length,
                              itemBuilder: (context, i) => _WordCard(
                                word: words[i],
                                color: Gj.festive[i % Gj.festive.length],
                                saying: _saying == words[i].word.word,
                                onTap: () => _say(words[i]),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.color, required this.saying, required this.onTap});
  final JarWord word;
  final Color color;
  final bool saying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = App.of(context).store;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: saying ? 1.05 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: saying ? Gj.marigold : color, width: 4),
            boxShadow: [BoxShadow(color: Gj.edge(color).withValues(alpha: 0.5), offset: const Offset(0, 5))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(image: FileImage(store.file(word.photo)), fit: BoxFit.cover, gaplessPlayback: true),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Icon(saying ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, size: 20, color: color),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word.word,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Gj.edge(color), height: 1.1),
                    ),
                    Text(
                      word.word.meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Gj.inkSoft, height: 1.15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
