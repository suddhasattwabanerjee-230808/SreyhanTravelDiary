import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Settings and error notes, kept by Android itself (MainActivity.kt).
class AppChannel {
  static const _channel = MethodChannel('sreyhan/app');

  static Future<Map<String, Object?>> prefs() async =>
      Map<String, Object?>.from(await _channel.invokeMapMethod<String, Object?>('prefs') ?? const {});

  static Future<void> setPref(String key, Object? value) => _channel.invokeMethod('setPref', {'key': key, 'value': value});

  static Future<void> logError(String text) => _channel.invokeMethod('logError', {'text': text});
}

final _reported = <String>{};

/// Notes an error in Download (SreyhanDiary-crash-…-dart.txt), once per kind,
/// and carries on.
void reportError(Object error, StackTrace? stack) {
  final text = 'Dart error: $error\n\n$stack';
  debugPrint(text);
  if (!_reported.add('$error')) return;
  AppChannel.logError(text).catchError((Object _) {});
}

/// The app's saved settings. Not the shared_preferences plugin: in release
/// builds it never answers, and 0.4.0 waited on it forever at a black screen.
/// Read once; a failed or slow read gives empty settings, never a hang.
class Prefs {
  Prefs(this._values);

  /// For tests and previews: nothing saved anywhere.
  Prefs.memory() : _values = {}, _memory = true;

  final Map<String, Object?> _values;
  bool _memory = false;

  static Future<Prefs> load() => AppChannel.prefs()
      .timeout(const Duration(seconds: 3))
      .then(Prefs.new, onError: (Object e, StackTrace st) {
        reportError("Couldn't read the settings: $e", st);
        return Prefs({});
      });

  bool? getBool(String key) => _values[key] as bool?;

  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
    if (_memory) return;
    await AppChannel.setPref(key, value).catchError((Object e, StackTrace st) {
      reportError("Couldn't save \"$key\": $e", st);
    });
  }
}
