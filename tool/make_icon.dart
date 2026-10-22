// Draws the launcher icon from the app's own Sheru painter:
//   flutter test tool/make_icon.dart
// Writes the classic square icons (mipmap-*/ic_launcher.png) and the two
// layers of Android's adaptive icon (ic_launcher_foreground/_background).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sreyhan_diary/theme.dart';
import 'package:sreyhan_diary/widgets/sheru.dart';

const _res = 'android/app/src/main/res';
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

/// Sky blue, brighter in the middle, with a ring of white bandhani dots.
void _background(Canvas c, double size) {
  final rect = Offset.zero & Size.square(size);
  c.drawRect(
    rect,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.1),
        radius: 0.75,
        colors: [Color(0xFF9FE0FF), Gj.skyTop, Gj.peacock],
        stops: [0, 0.55, 1],
      ).createShader(rect),
  );
  final dot = Paint()..color = Colors.white.withValues(alpha: 0.35);
  for (final (ring, count, r) in [(0.43, 20, 0.014), (0.36, 14, 0.010)]) {
    for (var i = 0; i < count; i++) {
      final a = i / count * 2 * pi + ring;
      c.drawCircle(Offset(size / 2 + cos(a) * size * ring, size / 2 + sin(a) * size * ring), size * r, dot);
    }
  }
}

void _sheru(Canvas c, double size, double scale) {
  final s = size * scale;
  c.save();
  c.translate((size - s) / 2, (size - s) / 2 + size * 0.01);
  SheruPainter().paint(c, Size.square(s));
  c.restore();
}

Future<void> _png(String path, int px, void Function(Canvas c, double size) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec), px.toDouble());
  final img = await rec.endRecording().toImage(px, px);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('launcher icon', () async {
    for (final MapEntry(key: d, value: k) in _densities.entries) {
      // Classic icon: 48dp, a rounded square.
      final px = (48 * k).round();
      await _png('$_res/mipmap-$d/ic_launcher.png', px, (c, size) {
        final r = RRect.fromRectAndRadius(Offset.zero & Size.square(size), Radius.circular(size * 0.22));
        c.clipRRect(r);
        _background(c, size);
        _sheru(c, size, 0.86);
      });
      // Adaptive layers: 108dp, of which the middle 66dp is always shown.
      final layer = (108 * k).round();
      await _png('$_res/mipmap-$d/ic_launcher_background.png', layer, _background);
      await _png('$_res/mipmap-$d/ic_launcher_foreground.png', layer, (c, size) => _sheru(c, size, 0.6));
    }
    File('$_res/mipmap-anydpi-v26/ic_launcher.xml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<!-- Sheru on a sky of bandhani dots; drawn by tool/make_icon.dart. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''');
  });
}
