// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Loest auf Web einen Browser-Download fuer die uebergebenen Bytes aus.
///
/// Verwendet Blob + ObjectURL (kein base64 data-URL), damit auch grosse
/// Dateien (>2MB) zuverlaessig heruntergeladen werden — data-URLs scheitern
/// in einigen Browsern oberhalb der 2MB-Grenze.
void downloadBytes(List<int> bytes, String filename, String mimeType) {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = filename
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
