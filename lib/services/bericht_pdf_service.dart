import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bericht.dart';
import 'praxis_briefpapier.dart';

/// Erstellt ein professionell formatiertes PDF im Briefpapier-Stil.
class BerichtPdfService {
  /// Erzeugt ein PDF-Dokument als Bytes.
  static Future<Uint8List> buildPdf({
    required Bericht bericht,
    required PraxisBriefpapier briefpapier,
  }) async {
    final doc = pw.Document(
      title: bericht.titel.isEmpty
          ? 'Bericht ${bericht.kategorie.label}'
          : bericht.titel,
      author: bericht.authorName ?? bericht.authorEmail,
      creator: 'WarteListe Pro',
      subject: bericht.kategorie.label,
    );

    final base = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
      italic: await PdfGoogleFonts.interItalic(),
    );

    final fmtDate = DateFormat('dd.MM.yyyy');
    final color = _pdfColorFor(bericht.kategorie);
    final accent = PdfColor.fromInt(0xFF1A3FA0); // Menauer-Blau, sonst neutral

    // Logo als pw.Image (falls vorhanden)
    final pw.Widget? logoWidget = briefpapier.logoBytes != null
        ? pw.Image(pw.MemoryImage(briefpapier.logoBytes!),
            width: 70, height: 70, fit: pw.BoxFit.contain)
        : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 28,
          marginBottom: 28,
          marginLeft: 36,
          marginRight: 36,
        ),
        theme: base,
        header: (ctx) =>
            _buildHeader(briefpapier, logoWidget, accent, ctx, fmtDate),
        footer: (ctx) => _buildFooter(briefpapier, accent, ctx),
        build: (ctx) => [
          // ── Empfänger-Block (links) — bei patientbezogenem Bericht ──
          if (bericht.patientName != null && bericht.patientName!.isNotEmpty)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(color: color, width: 2),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PATIENT',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                              letterSpacing: 1.0,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            bericht.patientName!,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Kategorie-Tag (kleiner, rechts) ──
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: color.shade(0.92),
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: color, width: 0.6),
                ),
                child: pw.Text(
                  bericht.kategorie.label.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: color,
                    letterSpacing: 1.2,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // ── Betreff / Titel ──
          pw.Text(
            bericht.titel.isEmpty ? '(ohne Titel)' : bericht.titel,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
              letterSpacing: -0.3,
            ),
          ),
          pw.SizedBox(height: 4),

          // ── Meta-Zeile (Verfasser · Datum · ggf. Aktualisiert) ──
          pw.Row(
            children: [
              pw.Text(
                'Verfasst von ${bericht.authorName ?? bericht.authorEmail}',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Text(
                '  ·  ${DateFormat('dd.MM.yyyy · HH:mm').format(bericht.erstelltAm)}',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey600),
              ),
              if (bericht.aktualisiertAm != null)
                pw.Text(
                  '  ·  aktualisiert ${DateFormat('dd.MM.yyyy').format(bericht.aktualisiertAm!)}',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600),
                ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(height: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 14),

          // ── Inhalt: Quill Delta -> PDF widgets ──
          ..._renderQuillContent(bericht.inhalt, bericht.inhaltText),

          // ── Anhänge ──
          if (bericht.anhaenge.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ANHÄNGE',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                      letterSpacing: 1.0,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  ...bericht.anhaenge.map((a) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(
                          '• ${a.name}  (${a.dateigroesseLesbar})',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey800),
                        ),
                      )),
                ],
              ),
            ),
          ],

          // ── Schluss ──
          pw.SizedBox(height: 28),
          pw.Text(
            'Mit freundlichen Grüßen',
            style: const pw.TextStyle(
                fontSize: 11, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 32),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                        height: 0.6,
                        color: PdfColors.grey400,
                        margin: const pw.EdgeInsets.only(bottom: 4)),
                    pw.Text('Datum',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.SizedBox(width: 28),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                        height: 0.6,
                        color: PdfColors.grey400,
                        margin: const pw.EdgeInsets.only(bottom: 4)),
                    pw.Text(
                      bericht.authorName ?? bericht.authorEmail,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header: Logo links + Praxis-Name & Standort + Datum rechts ──
  static pw.Widget _buildHeader(PraxisBriefpapier b, pw.Widget? logoWidget,
      PdfColor accent, pw.Context ctx, DateFormat fmt) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      margin: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: accent, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoWidget != null) ...[
            logoWidget,
            pw.SizedBox(width: 14),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  b.praxisName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                    letterSpacing: -0.2,
                  ),
                ),
                if (b.standortAdresse.isNotEmpty)
                  pw.Text(
                    b.standortAdresse,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                if (b.standortTelefon.isNotEmpty)
                  pw.Text(
                    'Tel ${b.standortTelefon}'
                    '${b.standortFax != null ? "  ·  Fax ${b.standortFax}" : ""}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Datum',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                  letterSpacing: 0.8,
                ),
              ),
              pw.Text(
                fmt.format(DateTime.now()),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer: 3-Spalten (Verwaltung · Praxen · Bank) + Seitenzahl ──
  static pw.Widget _buildFooter(
      PraxisBriefpapier b, PdfColor accent, pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (b.footerBloecke.isNotEmpty)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: b.footerBloecke
                  .asMap()
                  .entries
                  .map((e) => pw.Expanded(
                        child: pw.Padding(
                          padding: pw.EdgeInsets.only(
                              right: e.key < b.footerBloecke.length - 1 ? 8 : 0),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                e.value.titel.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 7,
                                  color: accent,
                                  letterSpacing: 1.0,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              ...e.value.zeilen.map((z) => pw.Text(
                                    z,
                                    style: const pw.TextStyle(
                                      fontSize: 7,
                                      color: PdfColors.grey700,
                                      lineSpacing: 1,
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              if (b.website != null)
                pw.Text(
                  b.website!,
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: accent,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.Spacer(),
              pw.Text(
                'Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Konvertiert Quill-Delta-JSON in PDF-Widgets.
  static List<pw.Widget> _renderQuillContent(String inhalt, String fallback) {
    List<dynamic>? ops;
    try {
      final decoded = jsonDecode(inhalt);
      if (decoded is List) ops = decoded;
    } catch (_) {/* Plaintext */}

    if (ops == null) {
      return [
        pw.Text(
          (fallback.isNotEmpty ? fallback : inhalt),
          style: const pw.TextStyle(
            fontSize: 11,
            color: PdfColors.grey900,
            lineSpacing: 4,
          ),
        ),
      ];
    }

    final widgets = <pw.Widget>[];
    final inlineRuns = <_InlineRun>[];

    void flushParagraph(Map<String, dynamic>? blockAttrs) {
      if (inlineRuns.isEmpty &&
          (blockAttrs == null || blockAttrs['list'] == null)) {
        return;
      }

      String prefix = '';
      double indent = 0;
      pw.TextStyle baseStyle = const pw.TextStyle(
        fontSize: 11,
        color: PdfColors.grey900,
        lineSpacing: 3,
      );

      if (blockAttrs != null) {
        final h = blockAttrs['header'];
        if (h is num) {
          double size = 11;
          if (h == 1) {
            size = 18;
          } else if (h == 2) {
            size = 15;
          } else if (h == 3) {
            size = 13;
          }
          baseStyle = pw.TextStyle(
            fontSize: size,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          );
        }
        final list = blockAttrs['list'];
        if (list == 'bullet') {
          prefix = '•  ';
          indent = 6;
        } else if (list == 'ordered') {
          prefix = '•  ';
          indent = 6;
        } else if (list == 'checked') {
          prefix = '☑  ';
          indent = 6;
        } else if (list == 'unchecked') {
          prefix = '☐  ';
          indent = 6;
        }
      }

      final spans = <pw.TextSpan>[];
      if (prefix.isNotEmpty) {
        spans.add(pw.TextSpan(text: prefix, style: baseStyle));
      }
      for (final run in inlineRuns) {
        final s = baseStyle.copyWith(
          fontWeight: run.bold ? pw.FontWeight.bold : null,
          fontStyle: run.italic ? pw.FontStyle.italic : null,
          decoration: run.underline ? pw.TextDecoration.underline : null,
          color: run.code ? PdfColors.deepOrange : baseStyle.color,
        );
        spans.add(pw.TextSpan(text: run.text, style: s));
      }

      pw.Widget block = pw.Padding(
        padding: pw.EdgeInsets.only(left: indent, top: 2, bottom: 2),
        child: pw.RichText(text: pw.TextSpan(children: spans)),
      );
      if (blockAttrs?['blockquote'] == true) {
        block = pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.grey400, width: 2),
            ),
          ),
          child: block,
        );
      }
      widgets.add(block);
      inlineRuns.clear();
    }

    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      final attrs = (op['attributes'] as Map?)?.cast<String, dynamic>() ?? {};

      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          final segment = parts[i];
          final isLast = i == parts.length - 1;
          if (segment.isNotEmpty) {
            inlineRuns.add(_InlineRun(
              text: segment,
              bold: attrs['bold'] == true,
              italic: attrs['italic'] == true,
              underline: attrs['underline'] == true,
              code: attrs['code'] == true,
            ));
          }
          if (!isLast) {
            flushParagraph(insert == '\n' ? attrs : null);
          }
        }
      }
    }
    if (inlineRuns.isNotEmpty) flushParagraph(null);

    return widgets.isEmpty
        ? [
            pw.Text(
              fallback.isNotEmpty ? fallback : '(leer)',
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
            )
          ]
        : widgets;
  }

  static PdfColor _pdfColorFor(BerichtKategorie k) {
    switch (k) {
      case BerichtKategorie.verlaufsbericht:
        return PdfColor.fromInt(0xFF059669);
      case BerichtKategorie.anamnese:
        return PdfColor.fromInt(0xFF0F766E);
      case BerichtKategorie.telefonat:
        return PdfColor.fromInt(0xFF0891B2);
      case BerichtKategorie.uebergabe:
        return PdfColor.fromInt(0xFFD97706);
      case BerichtKategorie.allgemein:
        return PdfColor.fromInt(0xFF64748B);
    }
  }

  /// Loest die System-Druckansicht aus.
  static Future<void> druckeBericht({
    required Bericht bericht,
    required PraxisBriefpapier briefpapier,
  }) async {
    final bytes = await buildPdf(bericht: bericht, briefpapier: briefpapier);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _safeFilename(bericht),
    );
  }

  /// Teilt das PDF.
  static Future<void> teileBericht({
    required Bericht bericht,
    required PraxisBriefpapier briefpapier,
  }) async {
    final bytes = await buildPdf(bericht: bericht, briefpapier: briefpapier);
    await Printing.sharePdf(
      bytes: bytes,
      filename: _safeFilename(bericht),
    );
  }

  static String _safeFilename(Bericht b) {
    final fmt = DateFormat('yyyy-MM-dd');
    final titel = b.titel.replaceAll(RegExp(r'[^\w\säöüÄÖÜß-]'), '').trim();
    final patient =
        b.patientName?.replaceAll(RegExp(r'[^\w\säöüÄÖÜß-]'), '').trim() ?? '';
    final base = [
      fmt.format(b.erstelltAm),
      b.kategorie.label,
      if (patient.isNotEmpty) patient,
      if (titel.isNotEmpty) titel,
    ].join(' - ');
    return '$base.pdf';
  }
}

class _InlineRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool code;
  const _InlineRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.code = false,
  });
}

extension on PdfColor {
  PdfColor shade(double t) {
    return PdfColor(
      red + (1 - red) * t,
      green + (1 - green) * t,
      blue + (1 - blue) * t,
    );
  }
}
