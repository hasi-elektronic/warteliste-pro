import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum PatientStatus {
  wartend,
  platzGefunden,
  inBehandlung,
  abgeschlossen;

  String get label {
    switch (this) {
      case PatientStatus.wartend:
        return 'Wartend';
      case PatientStatus.platzGefunden:
        return 'Platz gefunden';
      case PatientStatus.inBehandlung:
        return 'In Behandlung';
      case PatientStatus.abgeschlossen:
        return 'Abgeschlossen';
    }
  }

  static PatientStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'wartend':
        return PatientStatus.wartend;
      case 'platzgefunden':
      case 'platz gefunden':
        return PatientStatus.platzGefunden;
      case 'inbehandlung':
      case 'in behandlung':
        return PatientStatus.inBehandlung;
      case 'abgeschlossen':
        return PatientStatus.abgeschlossen;
      default:
        return PatientStatus.wartend;
    }
  }
}

/// Prioritaet eines Patienten auf der Warteliste.
enum PatientPrioritaet {
  normal,
  hoch,
  dringend;

  String get label {
    switch (this) {
      case PatientPrioritaet.normal:
        return 'Normal';
      case PatientPrioritaet.hoch:
        return 'Hoch';
      case PatientPrioritaet.dringend:
        return 'Dringend';
    }
  }

  static PatientPrioritaet fromString(String value) {
    switch (value.toLowerCase()) {
      case 'hoch':
        return PatientPrioritaet.hoch;
      case 'dringend':
        return PatientPrioritaet.dringend;
      default:
        return PatientPrioritaet.normal;
    }
  }
}

class Patient {
  final String id;
  final DateTime anmeldung;
  final String name;
  final String vorname;
  final String adresse;
  final String telefon;
  final String versicherung;
  final String arzt;
  final String stoerungsbild;
  final String terminWunsch;
  final String weitereInfos;
  final DateTime? geburtsdatum;
  final PatientStatus status;
  final String? therapeutId;
  final DateTime? platzGefundenAm;
  final String monat;
  final String praxisId;

  // ── Rezept-Verwaltung ──
  final DateTime? rezeptDatum;
  final DateTime? rezeptGueltigBis;
  final int? verordnungsMenge; // Anzahl verordneter Einheiten

  // ── Kontakt-Tracking ──
  final DateTime? letzterKontakt;

  // ── Prioritaet ──
  final PatientPrioritaet prioritaet;

  const Patient({
    required this.id,
    required this.anmeldung,
    required this.name,
    required this.vorname,
    this.adresse = '',
    this.telefon = '',
    this.versicherung = 'KK',
    this.arzt = '',
    this.stoerungsbild = '',
    this.terminWunsch = 'flexibel',
    this.weitereInfos = '',
    this.geburtsdatum,
    this.status = PatientStatus.wartend,
    this.therapeutId,
    this.platzGefundenAm,
    required this.monat,
    required this.praxisId,
    this.rezeptDatum,
    this.rezeptGueltigBis,
    this.verordnungsMenge,
    this.letzterKontakt,
    this.prioritaet = PatientPrioritaet.normal,
  });

  /// Tage bis Rezept ablaeuft (negativ = bereits abgelaufen).
  int? get rezeptTageVerbleibend {
    if (rezeptGueltigBis == null) return null;
    return rezeptGueltigBis!.difference(DateTime.now()).inDays;
  }

  /// Ob das Rezept bald ablaeuft (< 14 Tage) oder bereits abgelaufen ist.
  bool get rezeptLaeuftAb {
    final tage = rezeptTageVerbleibend;
    if (tage == null) return false;
    return tage <= 14;
  }

  /// Ob das Rezept bereits abgelaufen ist.
  bool get rezeptAbgelaufen {
    final tage = rezeptTageVerbleibend;
    if (tage == null) return false;
    return tage < 0;
  }

  /// Ob der Patient ein Rezept hat.
  bool get hatRezept => rezeptDatum != null;

  /// Tage seit letztem Kontakt.
  int? get tageSeitLetztemKontakt {
    if (letzterKontakt == null) return null;
    return DateTime.now().difference(letzterKontakt!).inDays;
  }

  /// Ob der Kontakt ueberfaellig ist (> 30 Tage kein Kontakt).
  bool get kontaktUeberfaellig {
    final tage = tageSeitLetztemKontakt;
    if (tage == null) return status == PatientStatus.wartend; // kein Kontakt bei wartend = ueberfaellig
    return tage > 30 && status == PatientStatus.wartend;
  }

  /// Berechnet die Wartezeit in Tagen seit der Anmeldung.
  int get wartezeitInTagen {
    return DateTime.now().difference(anmeldung).inDays;
  }

  /// Vollstaendiger Name: "Vorname Name"
  String get vollstaendigerName => '$vorname $name'.trim();

  /// Factory: Erstellt Patient aus Firestore-Dokument.
  factory Patient.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Patient(
      id: doc.id,
      anmeldung: (data['anmeldung'] as Timestamp).toDate(),
      name: data['name'] as String? ?? '',
      vorname: data['vorname'] as String? ?? '',
      adresse: data['adresse'] as String? ?? '',
      telefon: data['telefon'] as String? ?? '',
      versicherung: data['versicherung'] as String? ?? 'KK',
      arzt: data['arzt'] as String? ?? '',
      stoerungsbild: data['stoerungsbild'] as String? ?? '',
      terminWunsch: data['terminWunsch'] as String? ?? 'flexibel',
      weitereInfos: data['weitereInfos'] as String? ?? '',
      geburtsdatum: data['geburtsdatum'] != null
          ? (data['geburtsdatum'] as Timestamp).toDate()
          : null,
      status: PatientStatus.fromString(data['status'] as String? ?? 'wartend'),
      therapeutId: data['therapeutId'] as String?,
      platzGefundenAm: data['platzGefundenAm'] != null
          ? (data['platzGefundenAm'] as Timestamp).toDate()
          : null,
      monat: data['monat'] as String? ?? '',
      praxisId: data['praxisId'] as String? ?? '',
      rezeptDatum: data['rezeptDatum'] != null
          ? (data['rezeptDatum'] as Timestamp).toDate()
          : null,
      rezeptGueltigBis: data['rezeptGueltigBis'] != null
          ? (data['rezeptGueltigBis'] as Timestamp).toDate()
          : null,
      verordnungsMenge: data['verordnungsMenge'] as int?,
      letzterKontakt: data['letzterKontakt'] != null
          ? (data['letzterKontakt'] as Timestamp).toDate()
          : null,
      prioritaet: PatientPrioritaet.fromString(
          data['prioritaet'] as String? ?? 'normal'),
    );
  }

  /// Konvertiert Patient zu Firestore-Map.
  Map<String, dynamic> toFirestore() {
    return {
      'anmeldung': Timestamp.fromDate(anmeldung),
      'name': name,
      'vorname': vorname,
      'adresse': adresse,
      'telefon': telefon,
      'versicherung': versicherung,
      'arzt': arzt,
      'stoerungsbild': stoerungsbild,
      'terminWunsch': terminWunsch,
      'weitereInfos': weitereInfos,
      'geburtsdatum':
          geburtsdatum != null ? Timestamp.fromDate(geburtsdatum!) : null,
      'status': status.name,
      'therapeutId': therapeutId,
      'platzGefundenAm':
          platzGefundenAm != null ? Timestamp.fromDate(platzGefundenAm!) : null,
      'monat': monat,
      'praxisId': praxisId,
      'rezeptDatum':
          rezeptDatum != null ? Timestamp.fromDate(rezeptDatum!) : null,
      'rezeptGueltigBis':
          rezeptGueltigBis != null ? Timestamp.fromDate(rezeptGueltigBis!) : null,
      'verordnungsMenge': verordnungsMenge,
      'letzterKontakt':
          letzterKontakt != null ? Timestamp.fromDate(letzterKontakt!) : null,
      'prioritaet': prioritaet.name,
    };
  }

  /// Factory: Erstellt Patient aus einer Excel-Zeile (`Map<String, dynamic>`).
  ///
  /// Erwartete Spalten (flexibel):
  /// Anmeldung, Name, Vorname, Adresse, Telefon, Versicherung,
  /// Arzt, Stoerungsbild, Termin-Wunsch, Weitere Infos, Geburtsdatum
  factory Patient.fromExcelRow({
    required Map<String, dynamic> row,
    required String praxisId,
    String? id,
  }) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is double) {
        // Excel serial date number
        return DateTime(1899, 12, 30).add(Duration(days: value.toInt()));
      }
      final str = value.toString().trim();
      if (str.isEmpty) return DateTime.now();
      try {
        return dateFormat.parse(str);
      } catch (_) {
        try {
          return DateTime.parse(str);
        } catch (_) {
          return DateTime.now();
        }
      }
    }

    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      if (str.isEmpty) return null;
      try {
        return parseDate(value);
      } catch (_) {
        return null;
      }
    }

    String getString(Map<String, dynamic> row, List<String> keys) {
      for (final key in keys) {
        final val = row[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString().trim();
        }
      }
      return '';
    }

    final anmeldung = parseDate(
      row['Anmeldung'] ?? row['anmeldung'] ?? row['Datum'],
    );

    final monatStr = DateFormat('yyyy-MM').format(anmeldung);

    return Patient(
      id: id ?? '',
      anmeldung: anmeldung,
      name: getString(row, ['Name', 'name', 'Nachname', 'nachname']),
      vorname: getString(row, ['Vorname', 'vorname']),
      adresse: getString(row, ['Adresse', 'adresse', 'Anschrift']),
      telefon: getString(row, ['Telefon', 'telefon', 'Tel', 'Tel.']),
      versicherung: getString(row, ['Versicherung', 'versicherung', 'Kasse']),
      arzt: getString(row, ['Arzt', 'arzt', 'Verordnender Arzt']),
      stoerungsbild: getString(row, [
        'Stoerungsbild',
        'stoerungsbild',
        'Störungsbild',
        'Diagnose',
      ]),
      terminWunsch: getString(row, [
        'Termin-Wunsch',
        'terminWunsch',
        'Terminwunsch',
        'Wunschtermin',
      ]),
      weitereInfos: getString(row, [
        'Weitere Infos',
        'weitereInfos',
        'Bemerkung',
        'Notiz',
      ]),
      geburtsdatum: parseOptionalDate(
        row['Geburtsdatum'] ?? row['geburtsdatum'] ?? row['Geb.'],
      ),
      status: PatientStatus.wartend,
      monat: monatStr,
      praxisId: praxisId,
    );
  }

  /// Erstellt eine Kopie mit optionalen Aenderungen.
  Patient copyWith({
    String? id,
    DateTime? anmeldung,
    String? name,
    String? vorname,
    String? adresse,
    String? telefon,
    String? versicherung,
    String? arzt,
    String? stoerungsbild,
    String? terminWunsch,
    String? weitereInfos,
    DateTime? geburtsdatum,
    bool clearGeburtsdatum = false,
    PatientStatus? status,
    String? therapeutId,
    bool clearTherapeutId = false,
    DateTime? platzGefundenAm,
    bool clearPlatzGefundenAm = false,
    String? monat,
    String? praxisId,
    DateTime? rezeptDatum,
    bool clearRezeptDatum = false,
    DateTime? rezeptGueltigBis,
    bool clearRezeptGueltigBis = false,
    int? verordnungsMenge,
    bool clearVerordnungsMenge = false,
    DateTime? letzterKontakt,
    bool clearLetzterKontakt = false,
    PatientPrioritaet? prioritaet,
  }) {
    return Patient(
      id: id ?? this.id,
      anmeldung: anmeldung ?? this.anmeldung,
      name: name ?? this.name,
      vorname: vorname ?? this.vorname,
      adresse: adresse ?? this.adresse,
      telefon: telefon ?? this.telefon,
      versicherung: versicherung ?? this.versicherung,
      arzt: arzt ?? this.arzt,
      stoerungsbild: stoerungsbild ?? this.stoerungsbild,
      terminWunsch: terminWunsch ?? this.terminWunsch,
      weitereInfos: weitereInfos ?? this.weitereInfos,
      geburtsdatum:
          clearGeburtsdatum ? null : (geburtsdatum ?? this.geburtsdatum),
      status: status ?? this.status,
      therapeutId:
          clearTherapeutId ? null : (therapeutId ?? this.therapeutId),
      platzGefundenAm: clearPlatzGefundenAm
          ? null
          : (platzGefundenAm ?? this.platzGefundenAm),
      monat: monat ?? this.monat,
      praxisId: praxisId ?? this.praxisId,
      rezeptDatum:
          clearRezeptDatum ? null : (rezeptDatum ?? this.rezeptDatum),
      rezeptGueltigBis: clearRezeptGueltigBis
          ? null
          : (rezeptGueltigBis ?? this.rezeptGueltigBis),
      verordnungsMenge: clearVerordnungsMenge
          ? null
          : (verordnungsMenge ?? this.verordnungsMenge),
      letzterKontakt: clearLetzterKontakt
          ? null
          : (letzterKontakt ?? this.letzterKontakt),
      prioritaet: prioritaet ?? this.prioritaet,
    );
  }

  @override
  String toString() =>
      'Patient(id: $id, name: $name, vorname: $vorname, status: ${status.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Patient && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
