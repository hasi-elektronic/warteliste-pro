// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web: XMLHttpRequest verwenden (zuverlaessiger als http package im Browser).
Future<String> uploadToR2({
  required String baseUrl,
  required String key,
  required Uint8List bytes,
  required String contentType,
}) async {
  final url = '$baseUrl/upload?key=$key';

  final request = html.HttpRequest();
  request.open('POST', url);
  request.setRequestHeader('Content-Type', contentType);

  final completer = Future<String>.delayed(Duration.zero, () async {
    request.send(html.Blob([bytes]));

    await request.onLoadEnd.first;

    if (request.status != 200) {
      throw Exception('Upload fehlgeschlagen: ${request.status} ${request.responseText}');
    }

    return '$baseUrl/file/$key';
  });

  return completer;
}

Future<void> deleteFromR2({required String url, required String baseUrl}) async {
  final key = url.replaceFirst('$baseUrl/file/', '');
  final request = html.HttpRequest();
  request.open('DELETE', '$baseUrl/file/$key');
  request.send();
  await request.onLoadEnd.first;
}
