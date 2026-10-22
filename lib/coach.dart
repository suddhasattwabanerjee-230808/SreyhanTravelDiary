import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'words.dart';

class CoachQuestions {
  const CoachQuestions(this.praise, this.questions);
  final String praise;
  final List<String> questions;
}

class SuperSentence {
  const SuperSentence({required this.sentences, this.newWords = const [], this.praise = ''});
  final List<String> sentences;
  final List<NewWord> newWords;
  final String praise;

  String get text => sentences.join(' ');
}

class BridgeWord {
  const BridgeWord(this.english, this.sentence);
  final String english;
  final String sentence;
}

/// Sheru's brain. Every call returns null when the coach can't help (no
/// internet, no coach set up, a slow or odd answer), and the screens carry on
/// offline.
abstract class Coach {
  bool get online;
  Future<CoachQuestions?> ask(String photoPath, String said);
  Future<SuperSentence?> polish(String photoPath, String said);
  Future<BridgeWord?> bridge(String said);
}

/// Without the coach: tidy the child's words into a sentence, no new words.
SuperSentence offlinePolish(String said) => SuperSentence(sentences: [tidySentence(said)]);

/// Talks to coach-worker/worker.js.
class HttpCoach implements Coach {
  HttpCoach(this.url, this.token, {http.Client? client, this.photoBytes = shrinkPhoto}) : _client = client ?? http.Client();

  final String url;
  final String token;
  final http.Client _client;

  /// Reads a photo as a small JPEG for the request.
  final Future<List<int>?> Function(String path) photoBytes;

  static const _timeout = Duration(seconds: 25);

  @override
  bool get online => url.isNotEmpty && token.isNotEmpty;

  @override
  Future<CoachQuestions?> ask(String photoPath, String said) async {
    final image = await _photo(photoPath);
    if (image == null) return null;
    final j = await _post({'action': 'ask', 'said': said, 'image': image});
    final questions = _strings(j?['questions']);
    if (questions.isEmpty) return null;
    return CoachQuestions((j!['praise'] as String?)?.trim() ?? '', questions);
  }

  @override
  Future<SuperSentence?> polish(String photoPath, String said) async {
    final image = await _photo(photoPath);
    final j = await _post({'action': 'polish', 'said': said, 'image': ?image});
    final sentences = _strings(j?['sentences']);
    if (sentences.isEmpty) return null;
    final text = sentences.join(' ').toLowerCase();
    return SuperSentence(
      sentences: sentences,
      praise: (j!['praise'] as String?)?.trim() ?? '',
      // Only words that really are in the sentence, so they can be highlighted.
      newWords: [
        for (final w in (j['newWords'] as List? ?? const []))
          if (w is Map && w['word'] is String && text.contains((w['word'] as String).toLowerCase()))
            NewWord((w['word'] as String).trim(), (w['meaning'] as String?)?.trim() ?? ''),
      ],
    );
  }

  @override
  Future<BridgeWord?> bridge(String said) async {
    final j = await _post({'action': 'bridge', 'said': said});
    final english = (j?['english'] as String?)?.trim() ?? '';
    if (english.isEmpty) return null;
    return BridgeWord(english, (j!['sentence'] as String?)?.trim() ?? '');
  }

  Future<String?> _photo(String path) async {
    try {
      final bytes = await photoBytes(path);
      return bytes == null ? null : base64Encode(bytes);
    } catch (e) {
      debugPrint('coach photo failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _post(Map<String, dynamic> body) async {
    if (!online) return null;
    try {
      final res = await _client
          .post(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) {
        debugPrint('coach ${body['action']}: ${res.statusCode} ${res.body}');
        return null;
      }
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('coach ${body['action']} failed: $e');
      return null;
    }
  }

  static List<String> _strings(Object? v) => [
    for (final s in (v is List ? v : const []))
      if (s is String && s.trim().isNotEmpty) s.trim(),
  ];
}

/// About 1024px on the short side is plenty for Sheru to see the photo.
Future<List<int>?> shrinkPhoto(String path) =>
    FlutterImageCompress.compressWithFile(path, minWidth: 1024, minHeight: 1024, quality: 80);
