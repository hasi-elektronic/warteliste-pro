import 'dart:typed_data';

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
