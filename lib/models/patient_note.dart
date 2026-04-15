import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Typ einer Patienten-Notiz.
enum NoteType {
  notiz,
  anruf,
  statusAenderung,
  email,
  rezept,
  dokument;

  String get label {
    switch (this) {
      case NoteType.notiz:
        return 'Notiz';
      case NoteType.anruf:
        return 'Anruf';
      case NoteType.statusAenderung:
        return 'Status';
      case NoteType.email:
        return 'E-Mail';
      case NoteType.rezept:
        return 'Rezept';
      case NoteType.dokument:
        return 'Dokument';
    }
  }

  String get icon {
    switch (this) {
      case NoteType.notiz:
        return 'note';
      case NoteType.anruf:
        return 'phone';
      case NoteType.statusAenderung:
        return 'swap';
      case NoteType.email:
        return 'email';
      case NoteType.rezept:
        return 'receipt';
      case NoteType.dokument:
        return 'attach_file';
    }
  }

  static NoteType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'anruf':
        return NoteType.anruf;
      case 'statusaenderung':
      case 'status':
        return NoteType.statusAenderung;
      case 'email':
        return NoteType.email;
      case 'rezept':
        return NoteType.rezept;
      case 'dokument':
        return NoteType.dokument;
      default:
        return NoteType.notiz;
    }
  }
}

/// Eine Notiz oder ein Anruf-Protokoll-Eintrag fuer einen Patienten.
class PatientNote {
  final String id;
  final String patientId;
  final String praxisId;
  final String inhalt;
  final NoteType typ;
  final DateTime erstelltAm;
  final String? erstelltVon;
  final String? dokumentUrl;
  final String? dokumentName;

  const PatientNote({
    required this.id,
    required this.patientId,
    required this.praxisId,
    required this.inhalt,
    this.typ = NoteType.notiz,
    required this.erstelltAm,
    this.erstelltVon,
    this.dokumentUrl,
    this.dokumentName,
  });

  /// Formatiertes Datum: "09.04.2026, 14:30"
  String get formatiertesDatum {
    return DateFormat('dd.MM.yyyy, HH:mm').format(erstelltAm);
  }

  /// Factory: Erstellt PatientNote aus Firestore-Dokument.
  factory PatientNote.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PatientNote(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      praxisId: data['praxisId'] as String? ?? '',
      inhalt: data['inhalt'] as String? ?? '',
      typ: NoteType.fromString(data['typ'] as String? ?? 'notiz'),
      erstelltAm: (data['erstelltAm'] as Timestamp).toDate(),
      erstelltVon: data['erstelltVon'] as String?,
      dokumentUrl: data['dokumentUrl'] as String?,
      dokumentName: data['dokumentName'] as String?,
    );
  }

  /// Konvertiert PatientNote zu Firestore-Map.
  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'praxisId': praxisId,
      'inhalt': inhalt,
      'typ': typ.name,
      'erstelltAm': Timestamp.fromDate(erstelltAm),
      'erstelltVon': erstelltVon,
      'dokumentUrl': dokumentUrl,
      'dokumentName': dokumentName,
    };
  }

  @override
  String toString() =>
      'PatientNote(id: $id, typ: ${typ.label}, inhalt: $inhalt)';
}
