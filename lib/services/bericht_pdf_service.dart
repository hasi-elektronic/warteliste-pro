import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bericht.dart';
import 'praxis_briefpapier.dart';

// Conditional import — Web vs Mobile
import 'pdf_platform_stub.dart'
    if (dart.library.html) 'pdf_platform_web.dart' as pdfPlatform;

/// Erstellt ein PDF im Briefpapier-Stil — Layout entspricht bewusst der
/// originalen Word-Vorlage von Logopädie Menauer:
///  • Logo oben rechts
///  • Praxis-Adresszeile oben links (klein, blau)
///  • Sidebar rechts (Verwaltung · Praxen · Internet · Bank) — auf jeder Seite
///  • Empfänger-Adresse links + Datum rechts (auf gleicher Höhe)
///  • Betrifft / Sehr geehrte / Inhalt / Mit freundlichen Grüßen
class BerichtPdfService {
  // ── Konstanten (Maße in pt) ───────────────────────────────────
  static const double _kSidebarWidth = 100;
  static const double _kSidebarRight = 22;
  static const double _kPageMarginLeft = 36;
  static const double _kPageMarginRight = 28 + _kSidebarWidth; // Platz fuer Sidebar
  static const double _kPageMarginTop = 110; // Platz nur fuer Logo
  static const double _kPageMarginBottom = 30;

  static final PdfColor _kAccentBlau = PdfColor.fromInt(0xFF1A3FA0);

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

    pw.ThemeData base;
    try {
      base = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.interRegular(),
        bold: await PdfGoogleFonts.interBold(),
        italic: await PdfGoogleFonts.interItalic(),
      );
    } catch (_) {
      base = pw.ThemeData.base();
    }

    final isBrief = bericht.kategorie == BerichtKategorie.brief;
    final fmtDate = DateFormat('dd.MM.yyyy');

    final pw.Widget? logoWidget = briefpapier.logoBytes != null
        ? pw.Image(
            pw.MemoryImage(briefpapier.logoBytes!),
            width: 80,
            height: 80,
            fit: pw.BoxFit.contain,
          )
        : null;

    doc.addPage(
      pw.MultiPage(
        theme: base,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: _kPageMarginLeft,
            marginRight: _kPageMarginRight,
            marginTop: _kPageMarginTop,
            marginBottom: _kPageMarginBottom,
          ),
          theme: base,
          buildBackground: (ctx) => _buildPageBackground(briefpapier, logoWidget),
        ),
        footer: (ctx) => _buildSeitenzahl(ctx),
        build: (ctx) => [
          // ── 1) Praxis-Adresszeile (klein, blau) ──────────────
          pw.Text(
            briefpapier.praxisName,
            style: pw.TextStyle(
              fontSize: 10,
              color: _kAccentBlau,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (briefpapier.standortAdresse.isNotEmpty)
            pw.Text(
              briefpapier.standortAdresse,
              style: pw.TextStyle(
                fontSize: 9,
                color: _kAccentBlau,
              ),
            ),
          pw.SizedBox(height: 26),

          // ── 2) Empfänger (links) + Datum (rechts) ────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildEmpfaengerBlock(bericht, isBrief),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 2),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Datum: ',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.TextSpan(
                        text: fmtDate.format(
                            bericht.briefDatum ?? DateTime.now()),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey900,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 28),

          // ── 3) Kategorie-Tag: bewusst NICHT im PDF.
          //   Der farbige Balken druckte auf manchen Geraeten als
          //   dunkler, unlesbarer Block (Kundenfeedback Menauer 07/2026).
          //   Die Kategorie steht bereits in den PDF-Metadaten.

          // ── 4) Betrifft / Titel ──────────────────────────────
          if (bericht.titel.isNotEmpty) ...[
            if (isBrief) ...[
              pw.Text(
                'Betrifft',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _sanitize(bericht.titel),
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey900,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 22),
            ] else ...[
              pw.Text(
                _sanitize(bericht.titel),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Verfasst von ${bericht.authorName ?? bericht.authorEmail} · '
                '${DateFormat('dd.MM.yyyy · HH:mm').format(bericht.erstelltAm)}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(height: 0.4, color: PdfColors.grey300),
              pw.SizedBox(height: 12),
            ],
          ],

          // ── 5) Inhalt (Quill Delta) ──────────────────────────
          ..._renderQuillContent(bericht.inhalt, bericht.inhaltText),

          // ── 6) Anhänge ───────────────────────────────────────
          if (bericht.anhaenge.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ANHÄNGE',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                      letterSpacing: 1.0,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  ...bericht.anhaenge.map((a) => pw.Text(
                        '• ${a.name}  (${a.dateigroesseLesbar})',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey800,
                        ),
                      )),
                ],
              ),
            ),
          ],

          // ── 7) Schluss (nur wenn Quill nicht selbst 'Mit freundlichen
          //     Grüßen' enthaelt — vermeidet Doppelung) ────────
          if (!_inhaltEnthaeltSchluss(bericht.inhaltText)) ...[
            pw.SizedBox(height: 28),
            pw.Text(
              'Mit freundlichen Grüßen',
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey900,
              ),
            ),
          ],
          pw.SizedBox(height: 36),
          pw.Container(
            width: 180,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(height: 0.6, color: PdfColors.grey400),
                pw.SizedBox(height: 3),
                pw.Text(
                  bericht.authorName ?? bericht.authorEmail,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Background: Logo + Sidebar als EIN Block ganz rechts.
  //   Logo zentriert oben, dann die Footer-Blöcke darunter.
  static pw.Widget _buildPageBackground(
      PraxisBriefpapier b, pw.Widget? logoWidget) {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(
        children: [
          pw.Positioned(
            top: 22,
            right: _kSidebarRight,
            bottom: _kPageMarginBottom + 14,
            child: pw.SizedBox(
              width: _kSidebarWidth - 4,
              child: _buildSidebar(b, logoWidget),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSidebar(
      PraxisBriefpapier b, pw.Widget? logoWidget) {
    final children = <pw.Widget>[];

    // ── Logo zentriert oben in der Sidebar ──
    if (logoWidget != null) {
      children.add(pw.Center(child: logoWidget));
      children.add(pw.SizedBox(height: 16));
    }

    if (b.footerBloecke.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      );
    }

    for (var i = 0; i < b.footerBloecke.length; i++) {
      final block = b.footerBloecke[i];
      children.add(pw.Text(
        block.titel,
        style: pw.TextStyle(
          fontSize: 8,
          color: _kAccentBlau,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      children.add(pw.SizedBox(height: 1));
      for (final z in block.zeilen) {
        children.add(pw.Text(
          z,
          style: pw.TextStyle(
            fontSize: 7.5,
            color: _kAccentBlau,
            lineSpacing: 1,
          ),
        ));
      }
      if (i < b.footerBloecke.length - 1) {
        children.add(pw.SizedBox(height: 8));
      }
    }

    if (b.website != null) {
      children.add(pw.SizedBox(height: 8));
      children.add(pw.Text(
        'Internet',
        style: pw.TextStyle(
          fontSize: 8,
          color: _kAccentBlau,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      children.add(pw.Text(
        b.website!,
        style: pw.TextStyle(
          fontSize: 7.5,
          color: _kAccentBlau,
        ),
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  static pw.Widget _buildEmpfaengerBlock(Bericht bericht, bool isBrief) {
    final lines = <String>[];
    if (bericht.patientName != null && bericht.patientName!.isNotEmpty) {
      lines.add(bericht.patientName!);
    } else if (isBrief) {
      // Default-Empfaenger-Platzhalter
      lines.addAll(['Frau / Herr', '[Name]', '[Straße]', '[PLZ Ort]']);
    }

    if (lines.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines
          .map((l) => pw.Text(
                l,
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey900,
                  lineSpacing: 2,
                ),
              ))
          .toList(),
    );
  }

  static pw.Widget _buildSeitenzahl(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
        style: const pw.TextStyle(
          fontSize: 8,
          color: PdfColors.grey500,
        ),
      ),
    );
  }

  /// Entfernt Unicode-Zeichen, die die PDF-Fonts nicht darstellen koennen
  /// und die als schwarze Tofu-Kaestchen drucken. iOS/iPad-Tastaturen
  /// fuegen bei Soft-Zeilenumbruechen U+2028 ein; Word-Paste bringt U+000B.
  /// Zeilentrenner werden zu echten Newlines, Steuerzeichen entfernt.
  static String _sanitize(String text) {
    return text
        .replaceAll('\u2028', '\n') // LINE SEPARATOR (iOS soft break)
        .replaceAll('\u2029', '\n') // PARAGRAPH SEPARATOR
        .replaceAll('\u000B', '\n') // VERTICAL TAB (Word)
        .replaceAll('\r', '')
        // Unsichtbare Zeichen: OBJ-Replacement, BOM, Soft-Hyphen,
        // Zero-Width-*, Word-Joiner, restliche Steuerzeichen.
        .replaceAll(
          RegExp(
            r'[\uFFFC\uFFFD\uFEFF\u00AD\u200B-\u200F\u2060'
            r'\u0000-\u0008\u000C\u000E-\u001F\u007F-\u009F]',
          ),
          '',
        );
  }

  // ── Quill Delta -> PDF widgets ─────────────────────────────────
  static List<pw.Widget> _renderQuillContent(String inhalt, String fallback) {
    List<dynamic>? ops;
    try {
      final decoded = jsonDecode(inhalt);
      if (decoded is List) ops = decoded;
    } catch (_) {/* Plaintext */}

    if (ops == null) {
      return [
        pw.Text(
          _sanitize(fallback.isNotEmpty ? fallback : inhalt),
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
        if (list == 'bullet' || list == 'ordered') {
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
        final parts = _sanitize(insert).split('\n');
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
              _sanitize(fallback.isNotEmpty ? fallback : '(leer)'),
              style: const pw.TextStyle(
                  fontSize: 11, color: PdfColors.grey800),
            )
          ]
        : widgets;
  }

  /// Erkennt ob der Plaintext-Inhalt schon einen Brief-Schluss enthaelt,
  /// damit das PDF kein zweites 'Mit freundlichen Grüßen' anhaengt.
  static bool _inhaltEnthaeltSchluss(String text) {
    final lower = text.toLowerCase();
    return lower.contains('mit freundlichen gr') ||
        lower.contains('mfg') ||
        lower.contains('herzliche grüße') ||
        lower.contains('hochachtungsvoll');
  }

  // ── Public API ────────────────────────────────────────────────
  static Future<void> druckeBericht({
    required Bericht bericht,
    required PraxisBriefpapier briefpapier,
  }) async {
    final bytes = await buildPdf(bericht: bericht, briefpapier: briefpapier);
    await pdfPlatform.showPdf(bytes, _safeFilename(bericht));
  }

  static Future<void> teileBericht({
    required Bericht bericht,
    required PraxisBriefpapier briefpapier,
  }) async {
    final bytes = await buildPdf(bericht: bericht, briefpapier: briefpapier);
    await pdfPlatform.sharePdf(bytes, _safeFilename(bericht));
  }

  static String _safeFilename(Bericht b) {
    final fmt = DateFormat('yyyy-MM-dd');
    final titel = b.titel.replaceAll(RegExp(r'[^\w\säöüÄÖÜß-]'), '').trim();
    final patient = b.patientName?.replaceAll(RegExp(r'[^\w\säöüÄÖÜß-]'), '').trim() ?? '';
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
