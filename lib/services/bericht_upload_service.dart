import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

// Conditional import (Web vs Mobile)
import 'r2_uploader_stub.dart'
    if (dart.library.html) 'r2_uploader_web.dart' as uploader;

/// Hochladen / Loeschen von Bericht-Anhaengen via R2.
class BerichtUploadService {
  static const r2Base = 'https://warteliste-pro-r2.hguencavdi.workers.dev';

  /// Laedt eine Datei hoch und gibt die oeffentliche URL zurueck.
  static Future<({String url, String key})> uploadAnhang({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String praxisId,
    required String berichtId,
  }) async {
    final uuid = const Uuid().v4();
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'bin';
    final key = 'praxen/$praxisId/berichte/$berichtId/$uuid.$ext';

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw Exception('Nicht angemeldet');
    }

    final url = await uploader.uploadToR2(
      baseUrl: r2Base,
      key: key,
      bytes: bytes,
      contentType: contentType,
      idToken: idToken,
    );

    return (url: url, key: key);
  }

  /// Erzeugt eine kurzlebige signierte URL fuer einen Anhang
  /// (10 Minuten gueltig, kein Auth-Header noetig).
  static Future<String> getSignedUrl(String fileUrl) async {
    // fileUrl ist z.B. https://...workers.dev/file/praxen/.../berichte/.../uuid.pdf
    // Wir extrahieren den Key aus der URL.
    final filePrefix = '$r2Base/file/';
    if (!fileUrl.startsWith(filePrefix)) {
      // Bereits eine andere URL — direkt zurueckgeben
      return fileUrl;
    }
    final key = fileUrl.substring(filePrefix.length).split('?').first;
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) throw Exception('Nicht angemeldet');

    final resp = await http.post(
      Uri.parse('$r2Base/sign?key=${Uri.encodeComponent(key)}'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Sign-Anfrage fehlgeschlagen: ${resp.statusCode} ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['url'] as String;
  }

  /// Loescht einen Anhang anhand der URL.
  static Future<void> deleteAnhang(String url) async {
    try {
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) return;
      await uploader.deleteFromR2(
        url: url,
        baseUrl: r2Base,
        idToken: idToken,
      );
    } catch (_) {}
  }
}
