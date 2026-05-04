// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web: PDF in neuem Tab oeffnen (mit Browser-Print-Preview).
Future<void> showPdf(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // Cleanup nach 1 Minute (Tab sollte längst geladen haben)
  Future.delayed(const Duration(minutes: 1), () {
    try {
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  });
}

/// Web: PDF als Download anbieten.
Future<void> sharePdf(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future.delayed(const Duration(seconds: 5), () {
    try {
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  });
}
