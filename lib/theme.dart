import 'package:flutter/material.dart';

// --- Palette ------------------------------------------------------------------
// Colours of Gujarat: marigold and kumkum from festivals, peacock blue and
// green from Mor, bandhani maroon, the white salt of the Rann and the warm sand
// of Kutch. Always light: it's a picture book, not a tool.

class Gj {
  static const marigold = Color(0xFFFFB300);
  static const saffron = Color(0xFFFF7A1A);
  static const kumkum = Color(0xFFE53950);
  static const maroon = Color(0xFF8E1B3A);
  static const peacock = Color(0xFF0A78B8);
  static const teal = Color(0xFF00A39A);
  static const leaf = Color(0xFF3DAA4A);
  static const lilac = Color(0xFF8B5CF6);
  static const sand = Color(0xFFFFF4DC);
  static const salt = Color(0xFFFDFCF7);
  static const ink = Color(0xFF2B2350);
  static const inkSoft = Color(0xFF6A6290);
  static const skyTop = Color(0xFF6ECBFF);
  static const skyMid = Color(0xFFB9EAFF);
  static const skyLow = Color(0xFFFFE2B0);

  /// Kite and bubble colours, in the order they're handed out.
  static const festive = [kumkum, marigold, peacock, leaf, lilac, saffron, teal, maroon];

  /// The darker "3D edge" under a coloured button.
  static Color edge(Color c) => Color.lerp(c, Colors.black, 0.28)!;
}

const fontFamily = 'Baloo2';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Gj.saffron,
      brightness: Brightness.light,
      primary: Gj.saffron,
      secondary: Gj.peacock,
      surface: Gj.sand,
    ),
    scaffoldBackgroundColor: Gj.sand,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Gj.ink, displayColor: Gj.ink),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// Big friendly text with a white outline, for titles over pictures.
class OutlinedTitle extends StatelessWidget {
  const OutlinedTitle(this.text, {super.key, this.size = 34, this.color = Gj.ink, this.stroke = 7});
  final String text;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: FontWeight.w800, height: 1.05);
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          ),
        ),
        Text(text, textAlign: TextAlign.center, style: style.copyWith(color: color)),
      ],
    );
  }
}

/// Each letter in its own festive colour, like a fair banner.
class RainbowTitle extends StatelessWidget {
  const RainbowTitle(this.text, {super.key, this.size = 36});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: FontWeight.w800, height: 1.0);
    final spans = <TextSpan>[];
    var i = 0;
    for (final ch in text.characters) {
      spans.add(TextSpan(text: ch, style: style.copyWith(color: ch == ' ' ? null : Gj.festive[i % 6])));
      if (ch != ' ') i++;
    }
    return Stack(
      children: [
        Text.rich(
          TextSpan(text: text),
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.22
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
            shadows: const [Shadow(color: Color(0x33000000), offset: Offset(0, 3), blurRadius: 4)],
          ),
        ),
        Text.rich(TextSpan(children: spans), textAlign: TextAlign.center),
      ],
    );
  }
}
