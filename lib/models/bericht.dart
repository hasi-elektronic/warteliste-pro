import 'package:cloud_firestore/cloud_firestore.dart';

import 'bericht_anhang.dart';

/// Kategorie eines Berichts.
enum BerichtKategorie {
  verordnungsbericht,
  brief,
  verlaufsbericht,
  anamnese,
  telefonat,
  uebergabe,
  allgemein;

  String get label {
    switch (this) {
      case BerichtKategorie.verordnungsbericht:
        return 'Verordnungs-Bericht';
      case BerichtKategorie.brief:
        return 'Brief';
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
      case BerichtKategorie.verordnungsbericht:
        return 'assignment';
      case BerichtKategorie.brief:
        return 'mail_outline';
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
      case BerichtKategorie.verordnungsbericht:
        // Strukturierte Daten — kein Plaintext-Vorlagentext.
        return '';
      case BerichtKategorie.brief:
        // Nur die Anrede + Inhalt — Empfaenger/Betrifft/Datum/Schluss
        // werden vom PDF-Generator automatisch erzeugt.
        return '''Sehr geehrte Damen und Herren,

[Hier den Inhalt des Schreibens einfügen]''';
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

  /// Inhalt als Quill-Delta-JSON (rich text mit Headings, Listen,
  /// Checkboxen). Bei alten Berichten aus 1.5.3 ist es Plain-Text.
  final String inhalt;

  /// Plain-Text-Version (fuer Suche & Vorschau, ohne Formatierung).
  final String inhaltText;

  /// Datei-Anhaenge (PDFs, Bilder).
  final List<BerichtAnhang> anhaenge;

  /// Optional: Datum, das im Brief erscheinen soll (z.B. fuer rueckdatierte
  /// Schreiben). Falls null, wird im PDF erstelltAm bzw. heute verwendet.
  final DateTime? briefDatum;

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
    this.inhaltText = '',
    this.anhaenge = const [],
    this.briefDatum,
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
      inhaltText: d['inhaltText'] as String? ?? (d['inhalt'] as String? ?? ''),
      anhaenge: (d['anhaenge'] as List<dynamic>? ?? [])
          .map((m) => BerichtAnhang.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      briefDatum: (d['briefDatum'] as Timestamp?)?.toDate(),
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
      'inhaltText': inhaltText,
      'anhaenge': anhaenge.map((a) => a.toMap()).toList(),
      'briefDatum':
          briefDatum != null ? Timestamp.fromDate(briefDatum!) : null,
    };
  }

  Bericht copyWith({
    String? id,
    String? titel,
    String? inhalt,
    String? inhaltText,
    BerichtKategorie? kategorie,
    DateTime? aktualisiertAm,
    String? patientId,
    String? patientName,
    List<BerichtAnhang>? anhaenge,
    DateTime? briefDatum,
    bool clearBriefDatum = false,
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
      inhaltText: inhaltText ?? this.inhaltText,
      anhaenge: anhaenge ?? this.anhaenge,
      briefDatum: clearBriefDatum ? null : (briefDatum ?? this.briefDatum),
    );
  }
}
