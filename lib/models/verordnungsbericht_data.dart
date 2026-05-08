import 'dart:convert';

/// Strukturierte Daten für einen Verordnungs-Bericht (Anhang A zu § 125 SGB V).
class VerordnungsberichtData {
  // Personalien
  final String name;
  final String vorname;
  final DateTime? geburtsdatum;

  // Verordnung
  final DateTime? verordnungsdatum;
  final String diagnosegruppe;
  final String therapeutischeDiagnose;

  // Empfehlungen — linke Spalte
  final bool empFortfuehrung;
  final bool empTherapiepause;
  final bool empBeendigung;
  final bool empWiedervorstellung;
  final String empWiedervorstellungText;
  final bool empAndereTherapie;
  final String empAndereTherapieText;

  // Empfehlungen — rechte Spalte
  final bool empEinzeltherapie;
  final String empEinzeltherapieMinuten;
  final bool empGruppentherapie;
  final String empGruppentherapieMinuten;
  final bool empDoppelbehandlung;
  final bool empFrequenz;
  final String empFrequenzText;
  final bool empHausbesuch;

  // Therapieverlauf + Datum + Stempel
  final String zusammenfassung;
  final DateTime? datum;

  /// Welcher Standort/Vordruck verwendet werden soll
  /// ('weil' | 'ditzingen' | 'vaihingen' | 'blanko')
  final String standortKey;

  const VerordnungsberichtData({
    this.name = '',
    this.vorname = '',
    this.geburtsdatum,
    this.verordnungsdatum,
    this.diagnosegruppe = '',
    this.therapeutischeDiagnose = '',
    this.empFortfuehrung = false,
    this.empTherapiepause = false,
    this.empBeendigung = false,
    this.empWiedervorstellung = false,
    this.empWiedervorstellungText = '',
    this.empAndereTherapie = false,
    this.empAndereTherapieText = '',
    this.empEinzeltherapie = false,
    this.empEinzeltherapieMinuten = '',
    this.empGruppentherapie = false,
    this.empGruppentherapieMinuten = '',
    this.empDoppelbehandlung = false,
    this.empFrequenz = false,
    this.empFrequenzText = '',
    this.empHausbesuch = false,
    this.zusammenfassung = '',
    this.datum,
    this.standortKey = 'blanko',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'vorname': vorname,
        'geburtsdatum': geburtsdatum?.toIso8601String(),
        'verordnungsdatum': verordnungsdatum?.toIso8601String(),
        'diagnosegruppe': diagnosegruppe,
        'therapeutischeDiagnose': therapeutischeDiagnose,
        'empFortfuehrung': empFortfuehrung,
        'empTherapiepause': empTherapiepause,
        'empBeendigung': empBeendigung,
        'empWiedervorstellung': empWiedervorstellung,
        'empWiedervorstellungText': empWiedervorstellungText,
        'empAndereTherapie': empAndereTherapie,
        'empAndereTherapieText': empAndereTherapieText,
        'empEinzeltherapie': empEinzeltherapie,
        'empEinzeltherapieMinuten': empEinzeltherapieMinuten,
        'empGruppentherapie': empGruppentherapie,
        'empGruppentherapieMinuten': empGruppentherapieMinuten,
        'empDoppelbehandlung': empDoppelbehandlung,
        'empFrequenz': empFrequenz,
        'empFrequenzText': empFrequenzText,
        'empHausbesuch': empHausbesuch,
        'zusammenfassung': zusammenfassung,
        'datum': datum?.toIso8601String(),
        'standortKey': standortKey,
      };

  factory VerordnungsberichtData.fromJson(Map<String, dynamic> j) {
    DateTime? parse(String? s) => s == null ? null : DateTime.tryParse(s);
    return VerordnungsberichtData(
      name: j['name'] as String? ?? '',
      vorname: j['vorname'] as String? ?? '',
      geburtsdatum: parse(j['geburtsdatum'] as String?),
      verordnungsdatum: parse(j['verordnungsdatum'] as String?),
      diagnosegruppe: j['diagnosegruppe'] as String? ?? '',
      therapeutischeDiagnose: j['therapeutischeDiagnose'] as String? ?? '',
      empFortfuehrung: j['empFortfuehrung'] as bool? ?? false,
      empTherapiepause: j['empTherapiepause'] as bool? ?? false,
      empBeendigung: j['empBeendigung'] as bool? ?? false,
      empWiedervorstellung: j['empWiedervorstellung'] as bool? ?? false,
      empWiedervorstellungText: j['empWiedervorstellungText'] as String? ?? '',
      empAndereTherapie: j['empAndereTherapie'] as bool? ?? false,
      empAndereTherapieText: j['empAndereTherapieText'] as String? ?? '',
      empEinzeltherapie: j['empEinzeltherapie'] as bool? ?? false,
      empEinzeltherapieMinuten: j['empEinzeltherapieMinuten'] as String? ?? '',
      empGruppentherapie: j['empGruppentherapie'] as bool? ?? false,
      empGruppentherapieMinuten:
          j['empGruppentherapieMinuten'] as String? ?? '',
      empDoppelbehandlung: j['empDoppelbehandlung'] as bool? ?? false,
      empFrequenz: j['empFrequenz'] as bool? ?? false,
      empFrequenzText: j['empFrequenzText'] as String? ?? '',
      empHausbesuch: j['empHausbesuch'] as bool? ?? false,
      zusammenfassung: j['zusammenfassung'] as String? ?? '',
      datum: parse(j['datum'] as String?),
      standortKey: j['standortKey'] as String? ?? 'blanko',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory VerordnungsberichtData.fromJsonString(String s) {
    try {
      return VerordnungsberichtData.fromJson(
          jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const VerordnungsberichtData();
    }
  }

  VerordnungsberichtData copyWith({
    String? name,
    String? vorname,
    DateTime? geburtsdatum,
    bool clearGeburtsdatum = false,
    DateTime? verordnungsdatum,
    bool clearVerordnungsdatum = false,
    String? diagnosegruppe,
    String? therapeutischeDiagnose,
    bool? empFortfuehrung,
    bool? empTherapiepause,
    bool? empBeendigung,
    bool? empWiedervorstellung,
    String? empWiedervorstellungText,
    bool? empAndereTherapie,
    String? empAndereTherapieText,
    bool? empEinzeltherapie,
    String? empEinzeltherapieMinuten,
    bool? empGruppentherapie,
    String? empGruppentherapieMinuten,
    bool? empDoppelbehandlung,
    bool? empFrequenz,
    String? empFrequenzText,
    bool? empHausbesuch,
    String? zusammenfassung,
    DateTime? datum,
    bool clearDatum = false,
    String? standortKey,
  }) {
    return VerordnungsberichtData(
      name: name ?? this.name,
      vorname: vorname ?? this.vorname,
      geburtsdatum:
          clearGeburtsdatum ? null : (geburtsdatum ?? this.geburtsdatum),
      verordnungsdatum: clearVerordnungsdatum
          ? null
          : (verordnungsdatum ?? this.verordnungsdatum),
      diagnosegruppe: diagnosegruppe ?? this.diagnosegruppe,
      therapeutischeDiagnose:
          therapeutischeDiagnose ?? this.therapeutischeDiagnose,
      empFortfuehrung: empFortfuehrung ?? this.empFortfuehrung,
      empTherapiepause: empTherapiepause ?? this.empTherapiepause,
      empBeendigung: empBeendigung ?? this.empBeendigung,
      empWiedervorstellung: empWiedervorstellung ?? this.empWiedervorstellung,
      empWiedervorstellungText:
          empWiedervorstellungText ?? this.empWiedervorstellungText,
      empAndereTherapie: empAndereTherapie ?? this.empAndereTherapie,
      empAndereTherapieText:
          empAndereTherapieText ?? this.empAndereTherapieText,
      empEinzeltherapie: empEinzeltherapie ?? this.empEinzeltherapie,
      empEinzeltherapieMinuten:
          empEinzeltherapieMinuten ?? this.empEinzeltherapieMinuten,
      empGruppentherapie: empGruppentherapie ?? this.empGruppentherapie,
      empGruppentherapieMinuten:
          empGruppentherapieMinuten ?? this.empGruppentherapieMinuten,
      empDoppelbehandlung: empDoppelbehandlung ?? this.empDoppelbehandlung,
      empFrequenz: empFrequenz ?? this.empFrequenz,
      empFrequenzText: empFrequenzText ?? this.empFrequenzText,
      empHausbesuch: empHausbesuch ?? this.empHausbesuch,
      zusammenfassung: zusammenfassung ?? this.zusammenfassung,
      datum: clearDatum ? null : (datum ?? this.datum),
      standortKey: standortKey ?? this.standortKey,
    );
  }
}
