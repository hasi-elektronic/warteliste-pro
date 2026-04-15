// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

/// Loest auf Web einen Browser-Download fuer die uebergebenen Bytes aus.
///
/// Erstellt einen Blob, generiert eine ObjectURL und klickt
/// programmatisch auf einen unsichtbaren Anchor-Link.
void downloadBytes(List<int> bytes, String filename, String mimeType) {
  final base64Data = base64Encode(bytes);
  final dataUrl = 'data:$mimeType;base64,$base64Data';

  final anchor = html.AnchorElement(href: dataUrl)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
