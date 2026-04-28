import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bericht.dart';

/// Erstellt ein professionell formatiertes PDF fuer einen Bericht.
class BerichtPdfService {
  /// Erzeugt ein PDF-Dokument als Bytes.
  ///
  /// [praxisName] erscheint im Kopf-Bereich (z.B. "Logopädie Menauer").
  /// [praxisAdresse] und [praxisTelefon] erscheinen im Footer (optional).
  static Future<Uint8List> buildPdf({
    required Bericht bericht,
    required String praxisName,
    String praxisAdresse = '',
    String praxisTelefon = '',
  }) async {
    final doc = pw.Document(
      title: bericht.titel.isEmpty
          ? 'Bericht ${bericht.kategorie.label}'
          : bericht.titel,
      author: bericht.authorName ?? bericht.authorEmail,
      creator: 'WarteListe Pro',
      subject: bericht.kategorie.label,
    );

    // Schriftarten laden — Inter via google_fonts (Google fetch waere kompliziert
    // zur Build-Zeit; PDF nutzt Standardschriftart, was robust ist).
    final base = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
      italic: await PdfGoogleFonts.interItalic(),
    );

    final fmt = DateFormat('dd.MM.yyyy · HH:mm');
    final color = _pdfColorFor(bericht.kategorie);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 24,
          marginBottom: 24,
          marginLeft: 32,
          marginRight: 32,
        ),
        theme: base,
        header: (ctx) => _buildHeader(praxisName, color, ctx),
        footer: (ctx) => _buildFooter(praxisName, praxisAdresse, praxisTelefon, ctx),
        build: (ctx) => [
          // Kategorie-Banner
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: color.shade(0.92),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: color, width: 0.6),
            ),
            child: pw.Text(
              bericht.kategorie.label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 10,
                color: color,
                letterSpacing: 1.2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          // Titel
          pw.Text(
            bericht.titel.isEmpty ? '(ohne Titel)' : bericht.titel,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 12),

          // Metadaten-Tabelle
          _buildMetaTable(bericht, fmt),
          pw.SizedBox(height: 18),

          // Trenner
          pw.Container(
            height: 1,
            color: PdfColors.grey300,
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
          ),
          pw.SizedBox(height: 12),

          // Inhalt
          pw.Text(
            bericht.inhalt,
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey900,
              lineSpacing: 4,
            ),
          ),

          // Unterschrift-Bereich (manuell)
          pw.SizedBox(height: 36),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                        height: 0.6,
                        color: PdfColors.grey400,
                        margin: const pw.EdgeInsets.only(bottom: 4)),
                    pw.Text(
                      'Datum',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 32),
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
                      'Unterschrift',
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

  static pw.Widget _buildHeader(
      String praxisName, PdfColor color, pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: color, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo-Element
          pw.Container(
            width: 28,
            height: 28,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'WP',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                praxisName.isEmpty ? 'WarteListe Pro' : praxisName,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.Text(
                'Bericht',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Text(
            DateFormat('dd.MM.yyyy').format(DateTime.now()),
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(String praxisName, String adresse,
      String telefon, pw.Context ctx) {
    final parts = <String>[
      if (praxisName.isNotEmpty) praxisName,
      if (adresse.isNotEmpty) adresse,
      if (telefon.isNotEmpty) telefon,
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              parts.join(' · '),
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
          ),
          pw.Text(
            'Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaTable(Bericht bericht, DateFormat fmt) {
    final rows = <List<String>>[];
    if (bericht.patientName != null && bericht.patientName!.isNotEmpty) {
      rows.add(['Patient', bericht.patientName!]);
    }
    rows.add(['Verfasser', bericht.authorName ?? bericht.authorEmail]);
    rows.add(['Erstellt am', fmt.format(bericht.erstelltAm)]);
    if (bericht.aktualisiertAm != null) {
      rows.add(['Aktualisiert', fmt.format(bericht.aktualisiertAm!)]);
    }
    rows.add(['Kategorie', bericht.kategorie.label]);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(110),
        1: pw.FlexColumnWidth(),
      },
      children: rows
          .map((row) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: pw.Text(
                      row[0],
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: pw.Text(
                      row[1],
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey900,
                      ),
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }

  static PdfColor _pdfColorFor(BerichtKategorie k) {
    switch (k) {
      case BerichtKategorie.verlaufsbericht:
        return PdfColor.fromInt(0xFF059669); // emerald
      case BerichtKategorie.anamnese:
        return PdfColor.fromInt(0xFF0F766E); // teal
      case BerichtKategorie.telefonat:
        return PdfColor.fromInt(0xFF0891B2); // cyan
      case BerichtKategorie.uebergabe:
        return PdfColor.fromInt(0xFFD97706); // amber
      case BerichtKategorie.allgemein:
        return PdfColor.fromInt(0xFF64748B); // slate
    }
  }

  /// Loest die System-Druckansicht aus (auch im Web).
  static Future<void> druckeBericht({
    required Bericht bericht,
    required String praxisName,
    String praxisAdresse = '',
    String praxisTelefon = '',
  }) async {
    final bytes = await buildPdf(
      bericht: bericht,
      praxisName: praxisName,
      praxisAdresse: praxisAdresse,
      praxisTelefon: praxisTelefon,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _safeFilename(bericht),
    );
  }

  /// Teilt das PDF ueber das System-Share-Sheet (oder ladet es im Web herunter).
  static Future<void> teileBericht({
    required Bericht bericht,
    required String praxisName,
    String praxisAdresse = '',
    String praxisTelefon = '',
  }) async {
    final bytes = await buildPdf(
      bericht: bericht,
      praxisName: praxisName,
      praxisAdresse: praxisAdresse,
      praxisTelefon: praxisTelefon,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: _safeFilename(bericht),
    );
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

extension on PdfColor {
  /// Lighter shade — mix with white at given t (0..1).
  PdfColor shade(double t) {
    return PdfColor(
      red + (1 - red) * t,
      green + (1 - green) * t,
      blue + (1 - blue) * t,
    );
  }
}
