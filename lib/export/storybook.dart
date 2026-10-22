import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../diary_store.dart';
import '../models.dart';
import '../widgets/sheru.dart';

const _maroon = PdfColor.fromInt(0xFF8E1B3A);
const _saffron = PdfColor.fromInt(0xFFFF7A1A);
const _ink = PdfColor.fromInt(0xFF2B2350);
const _soft = PdfColor.fromInt(0xFF6A6290);
const _sand = PdfColor.fromInt(0xFFFFF4DC);
const _tapes = [
  PdfColor.fromInt(0xFFE53950),
  PdfColor.fromInt(0xFFFFB300),
  PdfColor.fromInt(0xFF0A78B8),
  PdfColor.fromInt(0xFF3DAA4A),
  PdfColor.fromInt(0xFF8B5CF6),
];

/// A printable storybook: a cover, then one A5 page per moment with its photo
/// taped in and the child's words underneath. [days] oldest first.
Future<Uint8List> buildStorybook(DiaryStore store, List<DiaryDay> days, {required String childName}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Baloo2-600.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Baloo2-800.ttf'));
  final sheru = pw.MemoryImage(await paintToPng(SheruPainter(), 240));
  final doc = pw.Document(
    title: "$childName's Travel Diary",
    author: childName,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  const format = PdfPageFormat.a5;
  final moments = [for (final d in days) ...d.moments];
  final first = days.first.day, last = days.last.day;
  final when = days.length == 1 ? prettyDate(first) : '${shortDate(first)} to ${shortDate(last)} ${last.year}';

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Container(
        color: _sand,
        padding: const pw.EdgeInsets.all(36),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text("$childName's", style: pw.TextStyle(font: bold, fontSize: 30, color: _saffron)),
            pw.Text('Travel Diary', style: pw.TextStyle(font: bold, fontSize: 40, color: _maroon)),
            pw.SizedBox(height: 18),
            pw.SizedBox(width: 150, height: 150, child: pw.Image(sheru)),
            pw.SizedBox(height: 18),
            pw.Text(when, style: pw.TextStyle(fontSize: 18, color: _ink)),
            pw.Text(
              '${moments.length} ${moments.length == 1 ? 'picture' : 'pictures'}, in my own words',
              style: const pw.TextStyle(fontSize: 13, color: _soft),
            ),
          ],
        ),
      ),
    ),
  );

  var page = 0;
  for (final day in days) {
    for (final (i, m) in day.moments.indexed) {
      page++;
      final photo = await _photo(store, m);
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (i == 0 || page == 1)
                pw.Text(prettyDate(day.day), style: pw.TextStyle(font: bold, fontSize: 20, color: _maroon))
              else
                pw.SizedBox(height: 26),
              pw.SizedBox(height: 14),
              _tapedPhoto(photo, _tapes[page % _tapes.length]),
              pw.SizedBox(height: 18),
              pw.Text(m.text, style: const pw.TextStyle(fontSize: 19, color: _ink, lineSpacing: 3)),
              if (m.learned.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text(
                  'New words: ${m.learned.map((w) => w.word).join(', ')}',
                  style: pw.TextStyle(font: bold, fontSize: 13, color: _saffron),
                ),
              ],
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(_time(m.createdAt), style: const pw.TextStyle(fontSize: 11, color: _soft)),
                  pw.Text('$page', style: const pw.TextStyle(fontSize: 11, color: _soft)),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
  return doc.save();
}

pw.Widget _tapedPhoto(pw.ImageProvider? photo, PdfColor tape) => pw.Stack(
  overflow: pw.Overflow.visible,
  children: [
    pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE6DFCF), width: 1),
      ),
      child: pw.SizedBox(
        height: 250,
        width: double.infinity,
        child: photo == null ? pw.SizedBox() : pw.Image(photo, fit: pw.BoxFit.cover),
      ),
    ),
    pw.Positioned(
      top: -8,
      left: 120,
      child: pw.Container(width: 80, height: 18, color: PdfColor(tape.red, tape.green, tape.blue, 0.7)),
    ),
  ],
);

Future<pw.ImageProvider?> _photo(DiaryStore store, Moment m) async {
  final f = store.file(m.photo);
  if (!await f.exists()) return null;
  // The saved JPEG goes in as it is: no decoding, and full quality for printing.
  return pw.MemoryImage(await File(f.path).readAsBytes());
}

String _time(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Draws a painter (Sheru) into a square PNG, for places that aren't Flutter
/// screens, like the storybook.
Future<Uint8List> paintToPng(CustomPainter painter, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  painter.paint(canvas, ui.Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
