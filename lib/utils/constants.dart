/// String-Konstanten und Konfiguration fuer WarteListe Pro.
class AppConstants {
  AppConstants._();

  // ──────────────────────────────────────────────
  // App
  // ──────────────────────────────────────────────

  static const String appName = 'WarteListe Pro';
  static const String appVersion = '1.0.0';

  // ──────────────────────────────────────────────
  // Status-Labels
  // ──────────────────────────────────────────────

  static const String statusWartend = 'Wartend';
  static const String statusPlatzGefunden = 'Platz gefunden';
  static const String statusInBehandlung = 'In Behandlung';
  static const String statusAbgeschlossen = 'Abgeschlossen';

  static const List<String> statusLabels = [
    statusWartend,
    statusPlatzGefunden,
    statusInBehandlung,
    statusAbgeschlossen,
  ];

  // ──────────────────────────────────────────────
  // Stoerungsbilder (Logopaedie)
  // ──────────────────────────────────────────────

  static const List<String> stoerungsbilder = [
    'Dysphagie',
    'Dyslalie',
    'SES',
    'Aphasie',
    'Dysphonie',
    'Stottern',
    'Myofunktionelle Stoerung',
    'Autismus',
    'Parkinson',
    'Hoergeraet/CI',
    'Lispeln',
  ];

  // ──────────────────────────────────────────────
  // Versicherungsarten
  // ──────────────────────────────────────────────

  static const String versicherungKK = 'KK';
  static const String versicherungPrivat = 'Privat';

  static const List<String> versicherungsarten = [
    versicherungKK,
    versicherungPrivat,
  ];

  // ──────────────────────────────────────────────
  // Terminwuensche
  // ──────────────────────────────────────────────

  static const String terminFlexibel = 'flexibel';
  static const String terminVormittags = 'vormittags';
  static const String terminNachmittags = 'nachmittags';

  static const List<String> terminOptionen = [
    terminFlexibel,
    terminVormittags,
    terminNachmittags,
  ];

  // ──────────────────────────────────────────────
  // Firebase Collection Names
  // ──────────────────────────────────────────────

  static const String collectionPatienten = 'patienten';
  static const String collectionPraxen = 'praxen';
  static const String collectionTherapeuten = 'therapeuten';
  static const String collectionTermine = 'termine';
  static const String collectionUsers = 'users';
  static const String collectionNotes = 'notizen';

  // ──────────────────────────────────────────────
  // UI-Texte
  // ──────────────────────────────────────────────

  static const String labelAnmeldung = 'Anmeldung';
  static const String labelName = 'Name';
  static const String labelVorname = 'Vorname';
  static const String labelAdresse = 'Adresse';
  static const String labelTelefon = 'Telefon';
  static const String labelVersicherung = 'Versicherung';
  static const String labelArzt = 'Arzt';
  static const String labelStoerungsbild = 'Stoerungsbild';
  static const String labelTerminWunsch = 'Termin-Wunsch';
  static const String labelWeitereInfos = 'Weitere Infos';
  static const String labelGeburtsdatum = 'Geburtsdatum';
  static const String labelStatus = 'Status';
  static const String labelTherapeut = 'Therapeut';
  static const String labelWartezeit = 'Wartezeit';
  static const String labelTage = 'Tage';

  // ──────────────────────────────────────────────
  // Aktionen
  // ──────────────────────────────────────────────

  static const String actionSpeichern = 'Speichern';
  static const String actionAbbrechen = 'Abbrechen';
  static const String actionLoeschen = 'Loeschen';
  static const String actionBearbeiten = 'Bearbeiten';
  static const String actionHinzufuegen = 'Hinzufuegen';
  static const String actionImportieren = 'Importieren';
  static const String actionExportieren = 'Exportieren';
  static const String actionSuchen = 'Suchen';
}
