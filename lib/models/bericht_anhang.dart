import 'package:cloud_firestore/cloud_firestore.dart';

/// Anhang (Datei) eines Berichts.
class BerichtAnhang {
  final String id;
  final String name;
  final String url;
  final String contentType;
  final int groesseBytes;
  final DateTime hochgeladenAm;

  const BerichtAnhang({
    required this.id,
    required this.name,
    required this.url,
    required this.contentType,
    required this.groesseBytes,
    required this.hochgeladenAm,
  });

  bool get istBild =>
      contentType.startsWith('image/') ||
      RegExp(r'\.(jpe?g|png|webp|heic|gif)$', caseSensitive: false)
          .hasMatch(name);

  bool get istPdf =>
      contentType == 'application/pdf' ||
      name.toLowerCase().endsWith('.pdf');

  String get dateigroesseLesbar {
    if (groesseBytes < 1024) return '$groesseBytes B';
    if (groesseBytes < 1024 * 1024) {
      return '${(groesseBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(groesseBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory BerichtAnhang.fromMap(Map<String, dynamic> m) {
    return BerichtAnhang(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      url: m['url'] as String? ?? '',
      contentType: m['contentType'] as String? ?? 'application/octet-stream',
      groesseBytes: (m['groesseBytes'] as num?)?.toInt() ?? 0,
      hochgeladenAm: (m['hochgeladenAm'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'contentType': contentType,
      'groesseBytes': groesseBytes,
      'hochgeladenAm': Timestamp.fromDate(hochgeladenAm),
    };
  }
}
