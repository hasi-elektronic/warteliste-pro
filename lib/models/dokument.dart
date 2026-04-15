import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Typ eines hochgeladenen Dokuments.
enum DokumentTyp {
  foto,
  pdf;

  String get label {
    switch (this) {
      case DokumentTyp.foto:
        return 'Foto';
      case DokumentTyp.pdf:
        return 'PDF';
    }
  }

  static DokumentTyp fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pdf':
        return DokumentTyp.pdf;
      default:
        return DokumentTyp.foto;
    }
  }
}

/// Ein hochgeladenes Dokument (Foto oder PDF) fuer einen Patienten.
class Dokument {
  final String id;
  final String patientId;
  final String praxisId;
  final String name;
  final String url;
  final DokumentTyp typ;
  final DateTime erstelltAm;
  final String? erstelltVon;
  final int? groesseBytes;

  const Dokument({
    required this.id,
    required this.patientId,
    required this.praxisId,
    required this.name,
    required this.url,
    required this.typ,
    required this.erstelltAm,
    this.erstelltVon,
    this.groesseBytes,
  });

  /// Formatiertes Datum.
  String get formatiertesDatum =>
      DateFormat('dd.MM.yyyy, HH:mm').format(erstelltAm);

  /// Menschenlesbare Dateigroesse.
  String get groesseText {
    if (groesseBytes == null) return '';
    if (groesseBytes! < 1024) return '${groesseBytes} B';
    if (groesseBytes! < 1024 * 1024) {
      return '${(groesseBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(groesseBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory Dokument.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Dokument(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      praxisId: data['praxisId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      url: data['url'] as String? ?? '',
      typ: DokumentTyp.fromString(data['typ'] as String? ?? 'foto'),
      erstelltAm: data['erstelltAm'] != null
          ? (data['erstelltAm'] as Timestamp).toDate()
          : DateTime.now(),
      erstelltVon: data['erstelltVon'] as String?,
      groesseBytes: data['groesseBytes'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'praxisId': praxisId,
      'name': name,
      'url': url,
      'typ': typ.name,
      'erstelltAm': Timestamp.fromDate(erstelltAm),
      'erstelltVon': erstelltVon,
      'groesseBytes': groesseBytes,
    };
  }
}
