import 'package:cloud_firestore/cloud_firestore.dart';

/// Kategorie eines Berichts.
enum BerichtKategorie {
  verlaufsbericht,
  anamnese,
  telefonat,
  uebergabe,
  allgemein;

  String get label {
    switch (this) {
      case BerichtKategorie.verlaufsbericht:
        return 'Verlaufsbericht';
      case BerichtKategorie.anamnese:
        return 'Anamnese';
      case BerichtKategorie.telefonat:
        return 'Telefonat';
      case BerichtKategorie.uebergabe:
        return 'Übergabe';
      case BerichtKategorie.allgemein:
        return 'Allgemeine Notiz';
    }
  }

  /// Material Icon für diese Kategorie.
  String get iconName {
    switch (this) {
      case BerichtKategorie.verlaufsbericht:
        return 'trending_up';
      case BerichtKategorie.anamnese:
        return 'history_edu';
      case BerichtKategorie.telefonat:
        return 'phone_in_talk';
      case BerichtKategorie.uebergabe:
        return 'change_circle';
      case BerichtKategorie.allgemein:
        return 'sticky_note_2';
    }
  }

  static BerichtKategorie fromString(String value) {
    return BerichtKategorie.values.firstWhere(
      (k) => k.name == value,
      orElse: () => BerichtKategorie.allgemein,
    );
  }

  /// Vorlage-Text fuer die jeweilige Kategorie.
  String get vorlage {
    switch (this) {
      case BerichtKategorie.verlaufsbericht:
        return '''Sitzung: ___ von ___
Dauer: ___ Min.

Therapieziele:
•

Durchgeführte Übungen:
•

Beobachtungen / Fortschritt:


Empfehlungen für die nächste Sitzung:


Hausaufgaben:
• ''';
      case BerichtKategorie.anamnese:
        return '''Anlass der Vorstellung:


Bisherige Therapien:


Aktuelle Beschwerden:


Familienanamnese / Umfeld:


Erste Einschätzung:


Geplantes Vorgehen:
''';
      case BerichtKategorie.telefonat:
        return '''Datum/Uhrzeit: ___
Gesprächspartner: ___
Anlass:

Inhalt des Gesprächs:


Vereinbarungen / Ergebnis:


Wiedervorlage am: ___''';
      case BerichtKategorie.uebergabe:
        return '''Schicht / Datum: ___

Wichtige Vorfälle / Patienten:
•

Offene Aufgaben:
•

Termine / Anrufe heute:
•

Sonstige Hinweise:
''';
      case BerichtKategorie.allgemein:
        return '';
    }
  }
}

/// Ein formaler Bericht — vom Mitarbeiter geschrieben, optional patientbezogen.
class Bericht {
  final String id;
  final String praxisId;

  /// Optional: Wenn der Bericht zu einem bestimmten Patienten gehoert.
  final String? patientId;
  final String? patientName; // denormalisiert fuer Anzeige

  /// Verfasser (aus Firebase Auth).
  final String authorUid;
  final String authorEmail;
  final String? authorName; // optional Display-Name

  final DateTime erstelltAm;
  final DateTime? aktualisiertAm;

  final BerichtKategorie kategorie;
  final String titel;
  final String inhalt;

  const Bericht({
    required this.id,
    required this.praxisId,
    this.patientId,
    this.patientName,
    required this.authorUid,
    required this.authorEmail,
    this.authorName,
    required this.erstelltAm,
    this.aktualisiertAm,
    required this.kategorie,
    required this.titel,
    required this.inhalt,
  });

  factory Bericht.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Bericht(
      id: doc.id,
      praxisId: d['praxisId'] as String? ?? '',
      patientId: d['patientId'] as String?,
      patientName: d['patientName'] as String?,
      authorUid: d['authorUid'] as String? ?? '',
      authorEmail: d['authorEmail'] as String? ?? '',
      authorName: d['authorName'] as String?,
      erstelltAm: (d['erstelltAm'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aktualisiertAm: (d['aktualisiertAm'] as Timestamp?)?.toDate(),
      kategorie: BerichtKategorie.fromString(d['kategorie'] as String? ?? 'allgemein'),
      titel: d['titel'] as String? ?? '',
      inhalt: d['inhalt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'praxisId': praxisId,
      'patientId': patientId,
      'patientName': patientName,
      'authorUid': authorUid,
      'authorEmail': authorEmail,
      'authorName': authorName,
      'erstelltAm': Timestamp.fromDate(erstelltAm),
      'aktualisiertAm':
          aktualisiertAm != null ? Timestamp.fromDate(aktualisiertAm!) : null,
      'kategorie': kategorie.name,
      'titel': titel,
      'inhalt': inhalt,
    };
  }

  Bericht copyWith({
    String? id,
    String? titel,
    String? inhalt,
    BerichtKategorie? kategorie,
    DateTime? aktualisiertAm,
    String? patientId,
    String? patientName,
  }) {
    return Bericht(
      id: id ?? this.id,
      praxisId: praxisId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      authorUid: authorUid,
      authorEmail: authorEmail,
      authorName: authorName,
      erstelltAm: erstelltAm,
      aktualisiertAm: aktualisiertAm ?? this.aktualisiertAm,
      kategorie: kategorie ?? this.kategorie,
      titel: titel ?? this.titel,
      inhalt: inhalt ?? this.inhalt,
    );
  }
}
