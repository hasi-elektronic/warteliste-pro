import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Stub (Mobile/Desktop): http package verwenden.
Future<String> uploadToR2({
  required String baseUrl,
  required String key,
  required Uint8List bytes,
  required String contentType,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/upload?key=$key'),
    headers: {'Content-Type': contentType},
    body: bytes,
  );
  if (response.statusCode != 200) {
    throw Exception('Upload fehlgeschlagen: ${response.statusCode}');
  }
  return '$baseUrl/file/$key';
}

Future<void> deleteFromR2({required String url, required String baseUrl}) async {
  final key = url.replaceFirst('$baseUrl/file/', '');
  await http.delete(Uri.parse('$baseUrl/file/$key'));
}
