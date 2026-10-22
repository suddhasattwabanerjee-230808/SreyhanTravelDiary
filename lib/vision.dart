import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_channel.dart';
import 'theme.dart';

/// Names the things in a photo ("Camel", "Sky", "Sand"), on the phone, free
/// and offline (Google ML Kit's labeller, through PhotoLabels.kt).
abstract class PhotoLabeler {
  /// The most likely labels first; empty if nothing is recognised.
  Future<List<String>> labels(String path);
}

class DeviceLabeler implements PhotoLabeler {
  static const _channel = MethodChannel('sreyhan/labels');

  @override
  Future<List<String>> labels(String path) async {
    try {
      return (await _channel.invokeListMethod<String>('labels', {'path': path}).timeout(const Duration(seconds: 15))) ??
          const [];
    } catch (e, st) {
      reportError('Photo labels: $e', st);
      return const [];
    }
  }
}

/// The kinds of travel things Sheru knows how to ask about, and the I-Spy
/// card's nine squares.
enum Thing { animal, bird, water, tree, food, ride, building, sky, people }

class ThingInfo {
  const ThingInfo(this.name, this.icon, this.color, this.keywords, this.questions);
  final String name;
  final IconData icon;
  final Color color;

  /// Label words that count as this thing.
  final List<String> keywords;

  /// `{x}` becomes the label, `{a}` its "a"/"an".
  final List<String> questions;
}

const things = <Thing, ThingInfo>{
  Thing.animal: ThingInfo('Animal', Icons.pets_rounded, Gj.saffron, [
    'animal', 'dog', 'cat', 'horse', 'cow', 'cattle', 'camel', 'elephant', 'goat', 'sheep', 'monkey', 'lion',
    'tiger', 'deer', 'pet', 'zoo', 'butterfly', 'insect', 'donkey', 'buffalo', 'rabbit', 'fish',
  ], [
    'I see {a} {x}! What colour was it?',
    'Was the {x} big or small?',
    'Did the {x} make a sound?',
  ]),
  Thing.bird: ThingInfo('Bird', Icons.flutter_dash_rounded, Gj.peacock, [
    'bird', 'peacock', 'duck', 'parrot', 'flamingo', 'pigeon', 'crow', 'feather', 'swan', 'owl',
  ], [
    'I see {a} {x}! Where was it sitting?',
    'What colours were its feathers?',
  ]),
  Thing.water: ThingInfo('Water', Icons.water_rounded, Gj.teal, [
    'water', 'river', 'lake', 'sea', 'ocean', 'beach', 'waterfall', 'pool', 'pond', 'wave', 'coast',
  ], [
    'I see the {x}! Was the water cold or warm?',
    'What did you do near the {x}?',
  ]),
  Thing.tree: ThingInfo('Tree or flower', Icons.local_florist_rounded, Gj.leaf, [
    'tree', 'plant', 'flower', 'leaf', 'forest', 'garden', 'grass', 'petal', 'jungle', 'bush', 'park',
  ], [
    'I see {a} {x}! What colour was it?',
    'Did it smell nice?',
  ]),
  Thing.food: ThingInfo('Food', Icons.restaurant_rounded, Gj.kumkum, [
    'food', 'fruit', 'vegetable', 'cake', 'bread', 'dessert', 'snack', 'sweet', 'juice', 'tea', 'drink',
    'cuisine', 'meal', 'dish', 'rice', 'pizza', 'ice cream', 'candy', 'coffee', 'baked goods',
  ], [
    'Yum, {x}! How did it taste?',
    'Was it sweet, spicy or salty?',
  ]),
  Thing.ride: ThingInfo('Ride', Icons.directions_bus_rounded, Gj.lilac, [
    'car', 'bus', 'train', 'boat', 'bicycle', 'motorcycle', 'vehicle', 'airplane', 'aircraft', 'truck',
    'ship', 'wheel', 'rickshaw', 'scooter', 'cart',
  ], [
    'I see {a} {x}! Where were you going?',
    'Was the ride fast or slow?',
  ]),
  Thing.building: ThingInfo('Building', Icons.temple_hindu_rounded, Gj.maroon, [
    'building', 'temple', 'church', 'mosque', 'palace', 'fort', 'castle', 'tower', 'house', 'monument',
    'bridge', 'statue', 'city', 'architecture', 'shrine', 'museum', 'stairs',
  ], [
    'I see {a} {x}! What did you see there?',
    'Was the {x} old or new?',
  ]),
  Thing.sky: ThingInfo('Sky', Icons.wb_twilight_rounded, Gj.marigold, [
    'sky', 'cloud', 'sunset', 'sunrise', 'sun', 'moon', 'star', 'rainbow', 'night', 'dusk',
  ], [
    'Look at the {x}! What colours can you see?',
    'What time of day was it?',
  ]),
  Thing.people: ThingInfo('People', Icons.groups_rounded, Gj.saffron, [
    'person', 'people', 'crowd', 'smile', 'selfie', 'family', 'child', 'team', 'dance', 'friend',
  ], [
    'Who is in your photo?',
    'What were you all doing?',
  ]),
};

bool _hasWord(String text, String word) => RegExp('\\b${RegExp.escape(word)}s?\\b').hasMatch(text);

/// Which kind of thing a label is, if Sheru knows it.
Thing? thingOf(String label) {
  final l = label.toLowerCase();
  for (final e in things.entries) {
    if (e.value.keywords.any((k) => _hasWord(l, k))) return e.key;
  }
  return null;
}

/// Every kind of thing in a photo's labels.
Set<Thing> thingsIn(List<String> labels) => {for (final l in labels) ?thingOf(l)};

String _a(String word) => RegExp(r'^[aeiou]', caseSensitive: false).hasMatch(word) ? 'an' : 'a';

/// Sheru's questions about a photo from its labels: up to three, from the
/// first two things he recognises.
List<String> photoQuestions(List<String> labels) {
  final out = <String>[];
  final seen = <Thing>{};
  for (final label in labels) {
    final t = thingOf(label);
    if (t == null || !seen.add(t)) continue;
    final x = label.toLowerCase();
    for (final q in things[t]!.questions.take(seen.length == 1 ? 2 : 1)) {
      out.add(q.replaceAll('{x}', x).replaceAll('{a}', _a(x)));
    }
    if (seen.length == 2) break;
  }
  return out.take(3).toList();
}
