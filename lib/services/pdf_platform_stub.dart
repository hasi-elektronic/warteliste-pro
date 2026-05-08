import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Mobile/Desktop: nutzt printing package fuer System-Druck-/Share-Dialog.
Future<void> showPdf(Uint8List bytes, String filename) async {
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: filename,
  );
}

Future<void> sharePdf(Uint8List bytes, String filename) async {
  await Printing.sharePdf(bytes: bytes, filename: filename);
}

/// Mobile: HTML wird via Printing.layoutPdf in PDF konvertiert.
/// (Auf Mobile öffnen wir den nativen Druckdialog.)
Future<void> openHtmlForPrint(String htmlContent, String filename) async {
  // Konvertiere HTML zu PDF-Bytes via printing-Paket
  final bytes = await Printing.convertHtml(
    format: PdfPageFormat.a4,
    html: htmlContent,
  );
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: filename,
  );
}
