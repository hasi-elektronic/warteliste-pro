import 'package:flutter/material.dart';

/// Einfaches i18n-System fuer WarteListe Pro.
///
/// Nutzung in Widgets: `final s = S.of(context);` und dann `s.dashboard`.
/// Wird automatisch ueber [Localizations] aktualisiert, wenn der Locale wechselt.
class S {
  final Locale locale;
  const S(this.locale);

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S) ?? const S(Locale('de'));
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  static const List<Locale> supportedLocales = [
    Locale('de'),
    Locale('en'),
  ];

  bool get isGerman => locale.languageCode == 'de';

  String _t(String key) {
    return _strings[locale.languageCode]?[key] ??
        _strings['de']?[key] ??
        key;
  }

  // ───────── App ─────────
  String get appName => _t('appName');
  String get languageGerman => _t('languageGerman');
  String get languageEnglish => _t('languageEnglish');

  // ───────── Bottom Nav ─────────
  String get navDashboard => _t('navDashboard');
  String get navWarteliste => _t('navWarteliste');
  String get navStatistik => _t('navStatistik');
  String get navEinstellungen => _t('navEinstellungen');

  // ───────── Dashboard ─────────
  String get dashboardWartend => _t('dashboardWartend');
  String get dashboardPlatzGefunden => _t('dashboardPlatzGefunden');
  String get dashboardGesamt => _t('dashboardGesamt');
  String get dashboardAuslastung => _t('dashboardAuslastung');
  String dashboardAuslastungInfo(int versorgt, int gesamt) =>
      _t('dashboardAuslastungInfo')
          .replaceAll('{versorgt}', '$versorgt')
          .replaceAll('{gesamt}', '$gesamt');
  String get dashboardMonatlicheUebersicht =>
      _t('dashboardMonatlicheUebersicht');
  String get dashboardNeuerPatient => _t('dashboardNeuerPatient');
  String get dashboardBenachrichtigungen => _t('dashboardBenachrichtigungen');
  String get dashboardKeineBenachrichtigungen =>
      _t('dashboardKeineBenachrichtigungen');

  // ───────── Status ─────────
  String get statusWartend => _t('statusWartend');
  String get statusPlatzGefunden => _t('statusPlatzGefunden');
  String get statusInBehandlung => _t('statusInBehandlung');
  String get statusAbgeschlossen => _t('statusAbgeschlossen');

  // ───────── Warteliste ─────────
  String get wartelisteAlle => _t('wartelisteAlle');
  String get wartelistePatientSuchen => _t('wartelistePatientSuchen');
  String get wartelisteSortierenNach => _t('wartelisteSortierenNach');
  String get wartelisteSortDatum => _t('wartelisteSortDatum');
  String get wartelisteSortName => _t('wartelisteSortName');
  String get wartelisteSortWartezeit => _t('wartelisteSortWartezeit');

  // ───────── Patient Form ─────────
  String get patientNeuerTitel => _t('patientNeuerTitel');
  String get patientBearbeitenTitel => _t('patientBearbeitenTitel');
  String get labelName => _t('labelName');
  String get labelVorname => _t('labelVorname');
  String get labelTelefon => _t('labelTelefon');
  String get labelArzt => _t('labelArzt');
  String get labelStoerungsbild => _t('labelStoerungsbild');
  String get labelVersicherung => _t('labelVersicherung');
  String get labelTerminWunsch => _t('labelTerminWunsch');
  String get labelGeburtsdatum => _t('labelGeburtsdatum');
  String get labelWeitereInfos => _t('labelWeitereInfos');
  String get datumWaehlen => _t('datumWaehlen');
  String get geburtsdatumWaehlen => _t('geburtsdatumWaehlen');
  String get terminFlexibel => _t('terminFlexibel');
  String get terminVormittags => _t('terminVormittags');
  String get terminNachmittags => _t('terminNachmittags');

  // ───────── Aktionen ─────────
  String get speichern => _t('speichern');
  String get abbrechen => _t('abbrechen');
  String get loeschen => _t('loeschen');
  String get bearbeiten => _t('bearbeiten');
  String get hinzufuegen => _t('hinzufuegen');
  String get importieren => _t('importieren');
  String get exportieren => _t('exportieren');

  // ───────── Einstellungen ─────────
  String get einstellungenTitel => _t('einstellungenTitel');
  String get sektionPraxisProfil => _t('sektionPraxisProfil');
  String get sektionTherapeuten => _t('sektionTherapeuten');
  String get sektionDaten => _t('sektionDaten');
  String get sektionBenachrichtigungen => _t('sektionBenachrichtigungen');
  String get sektionKonto => _t('sektionKonto');
  String get sektionSprache => _t('sektionSprache');
  String get sektionAbout => _t('sektionAbout');

  String get praxisName => _t('praxisName');
  String get praxisInhaber => _t('praxisInhaber');
  String get praxisAdresse => _t('praxisAdresse');
  String get praxisTelefon => _t('praxisTelefon');

  String get therapeutHinzufuegen => _t('therapeutHinzufuegen');
  String get therapeutKeine => _t('therapeutKeine');
  String get aktiv => _t('aktiv');
  String get inaktiv => _t('inaktiv');

  String get excelImportieren => _t('excelImportieren');
  String get excelExportieren => _t('excelExportieren');

  String get pushBenachrichtigungen => _t('pushBenachrichtigungen');
  String get pushBeschreibung => _t('pushBeschreibung');

  String get email => _t('email');
  String get abmelden => _t('abmelden');
  String get spracheWaehlen => _t('spracheWaehlen');

  // ───────── Notizen ─────────
  String get notizenTitel => _t('notizenTitel');
  String get notizHinzufuegen => _t('notizHinzufuegen');
  String get anrufProtokollieren => _t('anrufProtokollieren');
  String get notizTypNotiz => _t('notizTypNotiz');
  String get notizTypAnruf => _t('notizTypAnruf');
  String get notizTypStatus => _t('notizTypStatus');
  String get notizPlaceholder => _t('notizPlaceholder');
  String get anrufPlaceholder => _t('anrufPlaceholder');
  String get notizKeine => _t('notizKeine');
  String get notizLoeschen => _t('notizLoeschen');
  String get notizLoeschenBestaetigung => _t('notizLoeschenBestaetigung');
  String get notizGespeichert => _t('notizGespeichert');
  String get anrufGespeichert => _t('anrufGespeichert');

  // ───────── Standorte ─────────
  String get standorteTitel => _t('standorteTitel');
  String get standortHinzufuegen => _t('standortHinzufuegen');
  String get standortWechseln => _t('standortWechseln');
  String get standortName => _t('standortName');
  String get standortEntfernen => _t('standortEntfernen');
  String standortGewechselt(String name) =>
      _t('standortGewechselt').replaceAll('{name}', name);

  // ───────── Mitarbeiter ─────────
  String get mitarbeiterTitel => _t('mitarbeiterTitel');
  String get mitarbeiterEinladen => _t('mitarbeiterEinladen');
  String get mitarbeiterEntfernen => _t('mitarbeiterEntfernen');
  String get rolleAdmin => _t('rolleAdmin');
  String get rolleMitarbeiter => _t('rolleMitarbeiter');

  // ───────── Rezept ─────────
  String get rezeptTitel => _t('rezeptTitel');
  String get rezeptDatum => _t('rezeptDatum');
  String get rezeptGueltigBis => _t('rezeptGueltigBis');
  String get rezeptVerordnungsMenge => _t('rezeptVerordnungsMenge');
  String get rezeptKein => _t('rezeptKein');
  String get rezeptAbgelaufen => _t('rezeptAbgelaufen');
  String rezeptLaeuftAb(int tage) =>
      _t('rezeptLaeuftAb').replaceAll('{tage}', '$tage');
  String rezeptGueltig(int tage) =>
      _t('rezeptGueltig').replaceAll('{tage}', '$tage');

  // ───────── Prioritaet ─────────
  String get prioritaet => _t('prioritaet');
  String get prioritaetNormal => _t('prioritaetNormal');
  String get prioritaetHoch => _t('prioritaetHoch');
  String get prioritaetDringend => _t('prioritaetDringend');

  // ───────── Kontakt ─────────
  String get letzterKontakt => _t('letzterKontakt');
  String get kontaktUeberfaellig => _t('kontaktUeberfaellig');
  String get keinKontakt => _t('keinKontakt');
  String get emailProtokollieren => _t('emailProtokollieren');
  String get emailPlaceholder => _t('emailPlaceholder');
  String get emailGespeichert => _t('emailGespeichert');

  // ───────── Therapeut Kapazitaet ─────────
  String get therapeutMaxPatienten => _t('therapeutMaxPatienten');
  String get therapeutFachgebiet => _t('therapeutFachgebiet');
  String therapeutAuslastung(int aktuell, int max) =>
      _t('therapeutAuslastung')
          .replaceAll('{aktuell}', '$aktuell')
          .replaceAll('{max}', '$max');
  String get therapeutVoll => _t('therapeutVoll');

  // ───────── Dashboard Warnungen ─────────
  String get dashboardWarnungen => _t('dashboardWarnungen');
  String dashboardRezeptWarnung(int anzahl) =>
      _t('dashboardRezeptWarnung').replaceAll('{anzahl}', '$anzahl');
  String dashboardKontaktWarnung(int anzahl) =>
      _t('dashboardKontaktWarnung').replaceAll('{anzahl}', '$anzahl');
  String get dashboardDurchschnittlicheWartezeit =>
      _t('dashboardDurchschnittlicheWartezeit');

  // ───────── About ─────────
  String get aboutVersion => _t('aboutVersion');
  String get aboutEntwicktVon => _t('aboutEntwicktVon');
  String get aboutDeveloperName => _t('aboutDeveloperName');
  String get aboutBeschreibung => _t('aboutBeschreibung');
  String get aboutCopyright => _t('aboutCopyright');

  static const Map<String, Map<String, String>> _strings = {
    'de': {
      // App
      'appName': 'WarteListe Pro',
      'languageGerman': 'Deutsch',
      'languageEnglish': 'Englisch',

      // Nav
      'navDashboard': 'Dashboard',
      'navWarteliste': 'Warteliste',
      'navStatistik': 'Statistik',
      'navEinstellungen': 'Einstellungen',

      // Dashboard
      'dashboardWartend': 'Wartend',
      'dashboardPlatzGefunden': 'Platz gefunden',
      'dashboardGesamt': 'Gesamt',
      'dashboardAuslastung': 'Auslastung',
      'dashboardAuslastungInfo': '{versorgt} von {gesamt} Patienten versorgt',
      'dashboardMonatlicheUebersicht': 'Monatliche Übersicht',
      'dashboardNeuerPatient': 'Neuer Patient',
      'dashboardBenachrichtigungen': 'Benachrichtigungen',
      'dashboardKeineBenachrichtigungen': 'Keine neuen Benachrichtigungen',

      // Status
      'statusWartend': 'Wartend',
      'statusPlatzGefunden': 'Platz gefunden',
      'statusInBehandlung': 'In Behandlung',
      'statusAbgeschlossen': 'Abgeschlossen',

      // Warteliste
      'wartelisteAlle': 'Alle',
      'wartelistePatientSuchen': 'Patient suchen...',
      'wartelisteSortierenNach': 'Sortieren nach',
      'wartelisteSortDatum': 'Datum',
      'wartelisteSortName': 'Name',
      'wartelisteSortWartezeit': 'Wartezeit',

      // Patient Form
      'patientNeuerTitel': 'Neuer Patient',
      'patientBearbeitenTitel': 'Patient bearbeiten',
      'labelName': 'Name',
      'labelVorname': 'Vorname',
      'labelTelefon': 'Telefon',
      'labelArzt': 'Arzt',
      'labelStoerungsbild': 'Störungsbild',
      'labelVersicherung': 'Versicherung',
      'labelTerminWunsch': 'Termin-Wunsch',
      'labelGeburtsdatum': 'Geburtsdatum',
      'labelWeitereInfos': 'Weitere Infos',
      'datumWaehlen': 'Datum wählen',
      'geburtsdatumWaehlen': 'Geburtsdatum wählen',
      'terminFlexibel': 'flexibel',
      'terminVormittags': 'vormittags',
      'terminNachmittags': 'nachmittags',

      // Aktionen
      'speichern': 'Speichern',
      'abbrechen': 'Abbrechen',
      'loeschen': 'Löschen',
      'bearbeiten': 'Bearbeiten',
      'hinzufuegen': 'Hinzufügen',
      'importieren': 'Importieren',
      'exportieren': 'Exportieren',

      // Einstellungen
      'einstellungenTitel': 'Einstellungen',
      'sektionPraxisProfil': 'Praxis-Profil',
      'sektionTherapeuten': 'Therapeuten',
      'sektionDaten': 'Daten',
      'sektionBenachrichtigungen': 'Benachrichtigungen',
      'sektionKonto': 'Konto',
      'sektionSprache': 'Sprache',
      'sektionAbout': 'Über die App',
      'praxisName': 'Praxis Name',
      'praxisInhaber': 'Inhaber/in',
      'praxisAdresse': 'Adresse',
      'praxisTelefon': 'Telefon',
      'therapeutHinzufuegen': 'Therapeut hinzufügen',
      'therapeutKeine': 'Noch keine Therapeuten angelegt',
      'aktiv': 'Aktiv',
      'inaktiv': 'Inaktiv',
      'excelImportieren': 'Excel importieren',
      'excelExportieren': 'Excel exportieren',
      'pushBenachrichtigungen': 'Push-Benachrichtigungen',
      'pushBeschreibung': 'Benachrichtigungen bei neuen Anmeldungen',
      'email': 'E-Mail',
      'abmelden': 'Abmelden',
      'spracheWaehlen': 'Sprache wählen',

      // Notizen
      'notizenTitel': 'Notizen & Anrufe',
      'notizHinzufuegen': 'Notiz hinzufuegen',
      'anrufProtokollieren': 'Anruf protokollieren',
      'notizTypNotiz': 'Notiz',
      'notizTypAnruf': 'Anruf',
      'notizTypStatus': 'Status',
      'notizPlaceholder': 'Notiz eingeben...',
      'anrufPlaceholder': 'Ergebnis des Anrufs...',
      'notizKeine': 'Noch keine Notizen vorhanden',
      'notizLoeschen': 'Notiz loeschen?',
      'notizLoeschenBestaetigung': 'Diese Notiz unwiderruflich loeschen?',
      'notizGespeichert': 'Notiz gespeichert',
      'anrufGespeichert': 'Anruf protokolliert',

      // Standorte
      'standorteTitel': 'Standorte',
      'standortHinzufuegen': 'Neuen Standort hinzufuegen',
      'standortWechseln': 'Standort wechseln',
      'standortName': 'Standort-Name',
      'standortEntfernen': 'Standort entfernen',
      'standortGewechselt': 'Standort gewechselt: {name}',

      // Mitarbeiter
      'mitarbeiterTitel': 'Mitarbeiter',
      'mitarbeiterEinladen': 'Mitarbeiter einladen',
      'mitarbeiterEntfernen': 'Mitarbeiter entfernen',
      'rolleAdmin': 'Admin',
      'rolleMitarbeiter': 'Mitarbeiter',

      // Rezept
      'rezeptTitel': 'Rezept / Verordnung',
      'rezeptDatum': 'Rezept-Datum',
      'rezeptGueltigBis': 'Gültig bis',
      'rezeptGueltig': 'Gültig (noch {tage} Tage)',
      'rezeptVerordnungsMenge': 'Verordnungsmenge',
      'rezeptKein': 'Kein Rezept vorhanden',
      'rezeptAbgelaufen': 'Rezept abgelaufen!',
      'rezeptLaeuftAb': 'Rezept läuft in {tage} Tagen ab!',

      // Prioritaet
      'prioritaet': 'Priorität',
      'prioritaetNormal': 'Normal',
      'prioritaetHoch': 'Hoch',
      'prioritaetDringend': 'Dringend',

      // Kontakt
      'letzterKontakt': 'Letzter Kontakt',
      'kontaktUeberfaellig': 'Kontakt überfällig!',
      'keinKontakt': 'Noch kein Kontakt',
      'emailProtokollieren': 'E-Mail protokollieren',
      'emailPlaceholder': 'Betreff / Inhalt der E-Mail...',
      'emailGespeichert': 'E-Mail protokolliert',

      // Therapeut Kapazitaet
      'therapeutMaxPatienten': 'Max. Patienten',
      'therapeutFachgebiet': 'Fachgebiet',
      'therapeutAuslastung': '{aktuell}/{max} Plätze belegt',
      'therapeutVoll': 'Ausgebucht',

      // Dashboard Warnungen
      'dashboardWarnungen': 'Handlungsbedarf',
      'dashboardRezeptWarnung': '{anzahl} Rezepte laufen bald ab',
      'dashboardKontaktWarnung': '{anzahl} Patienten ohne Kontakt >30 Tage',
      'dashboardDurchschnittlicheWartezeit': 'Ø Wartezeit',

      // About
      'aboutVersion': 'Version',
      'aboutEntwicktVon': 'Entwickelt von',
      'aboutDeveloperName': 'Hasi Elektronic',
      'aboutBeschreibung':
          'Wartelisten-Management für Logopädie-Praxen',
      'aboutCopyright': '© 2026 Hasi Elektronic. Alle Rechte vorbehalten.',
    },
    'en': {
      // App
      'appName': 'WarteListe Pro',
      'languageGerman': 'German',
      'languageEnglish': 'English',

      // Nav
      'navDashboard': 'Dashboard',
      'navWarteliste': 'Waiting list',
      'navStatistik': 'Statistics',
      'navEinstellungen': 'Settings',

      // Dashboard
      'dashboardWartend': 'Waiting',
      'dashboardPlatzGefunden': 'Slot found',
      'dashboardGesamt': 'Total',
      'dashboardAuslastung': 'Capacity',
      'dashboardAuslastungInfo': '{versorgt} of {gesamt} patients served',
      'dashboardMonatlicheUebersicht': 'Monthly overview',
      'dashboardNeuerPatient': 'New patient',
      'dashboardBenachrichtigungen': 'Notifications',
      'dashboardKeineBenachrichtigungen': 'No new notifications',

      // Status
      'statusWartend': 'Waiting',
      'statusPlatzGefunden': 'Slot found',
      'statusInBehandlung': 'In treatment',
      'statusAbgeschlossen': 'Completed',

      // Warteliste
      'wartelisteAlle': 'All',
      'wartelistePatientSuchen': 'Search patient...',
      'wartelisteSortierenNach': 'Sort by',
      'wartelisteSortDatum': 'Date',
      'wartelisteSortName': 'Name',
      'wartelisteSortWartezeit': 'Waiting time',

      // Patient Form
      'patientNeuerTitel': 'New patient',
      'patientBearbeitenTitel': 'Edit patient',
      'labelName': 'Last name',
      'labelVorname': 'First name',
      'labelTelefon': 'Phone',
      'labelArzt': 'Doctor',
      'labelStoerungsbild': 'Diagnosis',
      'labelVersicherung': 'Insurance',
      'labelTerminWunsch': 'Preferred time',
      'labelGeburtsdatum': 'Date of birth',
      'labelWeitereInfos': 'Additional info',
      'datumWaehlen': 'Pick a date',
      'geburtsdatumWaehlen': 'Pick date of birth',
      'terminFlexibel': 'flexible',
      'terminVormittags': 'mornings',
      'terminNachmittags': 'afternoons',

      // Aktionen
      'speichern': 'Save',
      'abbrechen': 'Cancel',
      'loeschen': 'Delete',
      'bearbeiten': 'Edit',
      'hinzufuegen': 'Add',
      'importieren': 'Import',
      'exportieren': 'Export',

      // Einstellungen
      'einstellungenTitel': 'Settings',
      'sektionPraxisProfil': 'Practice profile',
      'sektionTherapeuten': 'Therapists',
      'sektionDaten': 'Data',
      'sektionBenachrichtigungen': 'Notifications',
      'sektionKonto': 'Account',
      'sektionSprache': 'Language',
      'sektionAbout': 'About',
      'praxisName': 'Practice name',
      'praxisInhaber': 'Owner',
      'praxisAdresse': 'Address',
      'praxisTelefon': 'Phone',
      'therapeutHinzufuegen': 'Add therapist',
      'therapeutKeine': 'No therapists yet',
      'aktiv': 'Active',
      'inaktiv': 'Inactive',
      'excelImportieren': 'Import Excel',
      'excelExportieren': 'Export Excel',
      'pushBenachrichtigungen': 'Push notifications',
      'pushBeschreibung': 'Get notified about new patients',
      'email': 'Email',
      'abmelden': 'Sign out',
      'spracheWaehlen': 'Select language',

      // Notes
      'notizenTitel': 'Notes & Calls',
      'notizHinzufuegen': 'Add note',
      'anrufProtokollieren': 'Log call',
      'notizTypNotiz': 'Note',
      'notizTypAnruf': 'Call',
      'notizTypStatus': 'Status',
      'notizPlaceholder': 'Enter note...',
      'anrufPlaceholder': 'Call result...',
      'notizKeine': 'No notes yet',
      'notizLoeschen': 'Delete note?',
      'notizLoeschenBestaetigung': 'Delete this note permanently?',
      'notizGespeichert': 'Note saved',
      'anrufGespeichert': 'Call logged',

      // Locations
      'standorteTitel': 'Locations',
      'standortHinzufuegen': 'Add new location',
      'standortWechseln': 'Switch location',
      'standortName': 'Location name',
      'standortEntfernen': 'Remove location',
      'standortGewechselt': 'Location switched: {name}',

      // Team members
      'mitarbeiterTitel': 'Team members',
      'mitarbeiterEinladen': 'Invite team member',
      'mitarbeiterEntfernen': 'Remove team member',
      'rolleAdmin': 'Admin',
      'rolleMitarbeiter': 'Staff',

      // Prescription
      'rezeptTitel': 'Prescription',
      'rezeptDatum': 'Prescription date',
      'rezeptGueltigBis': 'Valid until',
      'rezeptGueltig': 'Valid ({tage} days left)',
      'rezeptVerordnungsMenge': 'Prescribed units',
      'rezeptKein': 'No prescription',
      'rezeptAbgelaufen': 'Prescription expired!',
      'rezeptLaeuftAb': 'Prescription expires in {tage} days!',

      // Priority
      'prioritaet': 'Priority',
      'prioritaetNormal': 'Normal',
      'prioritaetHoch': 'High',
      'prioritaetDringend': 'Urgent',

      // Contact
      'letzterKontakt': 'Last contact',
      'kontaktUeberfaellig': 'Contact overdue!',
      'keinKontakt': 'No contact yet',
      'emailProtokollieren': 'Log email',
      'emailPlaceholder': 'Subject / email content...',
      'emailGespeichert': 'Email logged',

      // Therapist capacity
      'therapeutMaxPatienten': 'Max. patients',
      'therapeutFachgebiet': 'Specialty',
      'therapeutAuslastung': '{aktuell}/{max} slots taken',
      'therapeutVoll': 'Fully booked',

      // Dashboard warnings
      'dashboardWarnungen': 'Action needed',
      'dashboardRezeptWarnung': '{anzahl} prescriptions expiring soon',
      'dashboardKontaktWarnung': '{anzahl} patients without contact >30 days',
      'dashboardDurchschnittlicheWartezeit': 'Avg. wait time',

      // About
      'aboutVersion': 'Version',
      'aboutEntwicktVon': 'Developed by',
      'aboutDeveloperName': 'Hasi Elektronic',
      'aboutBeschreibung': 'Waiting list management for speech therapy practices',
      'aboutCopyright': '© 2026 Hasi Elektronic. All rights reserved.',
    },
  };
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['de', 'en'].contains(locale.languageCode);

  @override
  Future<S> load(Locale locale) async => S(locale);

  @override
  bool shouldReload(_SDelegate old) => false;
}
