import 'package:flutter/services.dart';

import 'app_channel.dart';
import 'places.dart';

/// Works out where a photo was taken, on the phone and offline: the photo's
/// own GPS tag, or for a photo just taken, where the phone is now
/// (PhotoPlace.kt). The place itself comes from places.dart, not the internet.
abstract class PlaceFinder {
  /// Null when it can't tell.
  Future<Place?> find(String path, {required bool camera});
}

/// Knows nowhere: for previews and tests.
class NoPlaces implements PlaceFinder {
  const NoPlaces();
  @override
  Future<Place?> find(String path, {required bool camera}) async => null;
}

class DevicePlaceFinder implements PlaceFinder {
  static const _channel = MethodChannel('sreyhan/place');

  @override
  Future<Place?> find(String path, {required bool camera}) async {
    try {
      final tags = await _channel.invokeMapMethod<String, Object?>('photo', {'path': path}).timeout(const Duration(seconds: 5));
      final spot = _latLng(tags);
      if (spot != null) return placeAt(spot.$1, spot.$2);
      // No GPS tag: a photo taken just now (or today, from the gallery) was
      // taken about here. The first time, Android asks about location, so
      // there's time to answer.
      final taken = tags?['taken'] as int?;
      final recent = taken != null && DateTime.now().millisecondsSinceEpoch - taken < const Duration(hours: 12).inMilliseconds;
      if (!camera && !recent) return null;
      final here = _latLng(await _channel.invokeMapMethod<String, Object?>('here').timeout(const Duration(seconds: 40)));
      return here == null ? null : placeAt(here.$1, here.$2);
    } catch (e, st) {
      reportError('Finding the place: $e', st);
      return null;
    }
  }

  static (double, double)? _latLng(Map<String, Object?>? m) {
    final lat = (m?['lat'] as num?)?.toDouble(), lng = (m?['lng'] as num?)?.toDouble();
    return lat == null || lng == null || (lat == 0 && lng == 0) ? null : (lat, lng);
  }
}
