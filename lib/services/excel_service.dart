import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';

/// Service fuer den Import und Export von Patienten-Daten im Excel-Format.
///
/// Unterstuetzt das Menauer-Wartelisten-Format mit monatlichen Tabellenblaettern
/// (Januar bis Dezember), Kopfzeilen in Zeile 1 und Zusammenfassungen am Ende.
class ExcelService {
  ExcelService();

  // ============================================================
  // Konstanten
  // ============================================================

  static const List<String> _monate = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  static const Map<String, String> _monatZuNummer = {
    'Januar': '01',
    'Februar': '02',
    'März': '03',
    'April': '04',
    'Mai': '05',
    'Juni': '06',
    'Juli': '07',
    'August': '08',
    'September': '09',
    'Oktober': '10',
    'November': '11',
    'Dezember': '12',
  };

  static const List<String> _exportHeaders = [
    'Anmeldung',
    'Therapeut',
    'Name',
    'Vorname',
    'Adresse',
    'Telefon',
    'KK/Privat',
    'Arzt',
    'Störungsbild',
    'Termine',
    'Weitere Infos',
  ];

  /// Zeilen am Ende, die uebersprungen werden sollen.
  static const List<String> _summaryKeywords = [
    'gesamt',
    'platz gefunden',
    'noch wartend',
    'auslastung',
    'summe',
  ];

  // ============================================================
  // Import
  // ============================================================

  /// Importiert Patienten aus einer Menauer-Excel-Datei.
  ///
  /// Liest alle Monatsblaetter (Januar-Dezember), parst jede Datenzeile
  /// und erstellt Patient-Objekte. Ueberspringt leere Zeilen und
  /// Zusammenfassungszeilen am Ende.
  ///
  /// Gibt eine Liste aller importierten Patienten zurueck.
  Future<List<Patient>> importFromExcel(
    String filePath,
    String praxisId,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Datei nicht gefunden', filePath);
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final List<Patient> patienten = [];
    final dateFormat = DateFormat('dd.MM.yyyy');

    for (final sheetName in excel.tables.keys) {
      final monatNummer = _monatZuNummer[sheetName];
      if (monatNummer == null) {
        // Kein bekannter Monatsname, ueberspringe dieses Blatt.
        continue;
      }

      final sheet = excel.tables[sheetName]!;
      if (sheet.maxRows < 3) continue; // Titel + Header + mind. 1 Zeile

      // Zeile 0 = Titel, Zeile 1 = Spaltenkoepfe, ab Zeile 2 = Daten
      final headerRow = sheet.row(1);
      final headers = headerRow
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .toList();

      for (int rowIndex = 2; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);

        // Leere Zeile erkennen
        final allEmpty = row.every(
          (cell) =>
              cell == null ||
              cell.value == null ||
              cell.value.toString().trim().isEmpty,
        );
        if (allEmpty) continue;

        // Zusammenfassungszeile erkennen
        final firstCellText =
            row.isNotEmpty && row[0] != null
                ? row[0]!.value.toString().trim().toLowerCase()
                : '';
        if (_summaryKeywords.any(
          (keyword) => firstCellText.contains(keyword),
        )) {
          continue;
        }

        // Zeile in Map umwandeln
        final Map<String, dynamic> rowMap = {};
        for (int col = 0; col < headers.length && col < row.length; col++) {
          if (headers[col].isNotEmpty) {
            rowMap[headers[col]] = row[col]?.value;
          }
        }

        // Therapeut-Spalte auswerten
        final therapeutValue =
            (rowMap['Therapeut'] ?? '').toString().trim();
        final hasPlatzGefunden = therapeutValue.toLowerCase().contains(
          'platz gefunden',
        );

        // Anmeldedatum parsen
        DateTime anmeldung;
        final rawAnmeldung = rowMap['Anmeldung'];
        if (rawAnmeldung is DateTime) {
          anmeldung = rawAnmeldung;
        } else if (rawAnmeldung is double) {
          // Excel serial date
          anmeldung = DateTime(1899, 12, 30).add(
            Duration(days: rawAnmeldung.toInt()),
          );
        } else {
          final str = rawAnmeldung?.toString().trim() ?? '';
          if (str.isEmpty) {
            anmeldung = DateTime.now();
          } else {
            try {
              anmeldung = dateFormat.parse(str);
            } catch (_) {
              try {
                anmeldung = DateTime.parse(str);
              } catch (_) {
                anmeldung = DateTime.now();
              }
            }
          }
        }

        // Monat bestimmen: Jahr aus Anmeldung + Monat aus Sheet
        final year = anmeldung.year;
        final monatStr = '$year-$monatNummer';

        final patient = Patient(
          id: '',
          anmeldung: anmeldung,
          name: _cellToString(rowMap['Name']),
          vorname: _cellToString(rowMap['Vorname']),
          adresse: _cellToString(rowMap['Adresse']),
          telefon: _cellToString(rowMap['Telefon']),
          versicherung: _cellToString(rowMap['KK/Privat']),
          arzt: _cellToString(rowMap['Arzt']),
          stoerungsbild: _cellToString(rowMap['Störungsbild']),
          terminWunsch: _cellToString(rowMap['Termine']),
          weitereInfos: _cellToString(rowMap['Weitere Infos']),
          status: hasPlatzGefunden
              ? PatientStatus.platzGefunden
              : PatientStatus.wartend,
          therapeutId: hasPlatzGefunden ? null : null,
          monat: monatStr,
          praxisId: praxisId,
        );

        patienten.add(patient);
      }
    }

    return patienten;
  }

  // ============================================================
  // Export
  // ============================================================

  /// Exportiert eine Liste von Patienten als Excel-Bytes.
  ///
  /// Wenn [monat] angegeben ist (Format 'yyyy-MM'), wird nur dieser Monat
  /// exportiert. Andernfalls werden alle vorhandenen Monate als separate
  /// Tabellenblaetter erstellt.
  ///
  /// Jedes Blatt hat:
  /// - Zeile 0: Titel ("Warteliste {Monat} {Jahr}")
  /// - Zeile 1: Spaltenkoepfe
  /// - Zeilen 2+: Patientendaten
  /// - Zusammenfassungszeilen am Ende
  Future<List<int>> exportToExcel(
    List<Patient> patienten, {
    String? monat,
  }) async {
    final excel = Excel.createExcel();

    // Standard-Sheet entfernen
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }

    final dateFormat = DateFormat('dd.MM.yyyy');

    // Patienten nach Monat gruppieren
    final Map<String, List<Patient>> grouped = {};
    if (monat != null) {
      grouped[monat] = patienten
          .where((p) => p.monat == monat)
          .toList();
    } else {
      for (final patient in patienten) {
        grouped.putIfAbsent(patient.monat, () => []).add(patient);
      }
    }

    // Sortierte Monatsliste
    final sortedMonths = grouped.keys.toList()..sort();

    for (final monatKey in sortedMonths) {
      final monatPatienten = grouped[monatKey]!;
      if (monatPatienten.isEmpty) continue;

      // Sheet-Name bestimmen: versuche deutschen Monatsnamen
      final sheetName = _monatKeyToSheetName(monatKey);
      final sheet = excel[sheetName];

      // Zeile 0: Titel
      sheet.appendRow([
        TextCellValue('Warteliste $sheetName'),
      ]);

      // Zeile 1: Header
      sheet.appendRow(
        _exportHeaders.map((h) => TextCellValue(h)).toList(),
      );

      // Zeilen 2+: Daten
      // Nach Anmeldedatum sortieren
      monatPatienten.sort((a, b) => a.anmeldung.compareTo(b.anmeldung));

      for (final patient in monatPatienten) {
        final therapeutText = patient.status == PatientStatus.platzGefunden
            ? 'Platz gefunden'
            : '';

        sheet.appendRow([
          TextCellValue(dateFormat.format(patient.anmeldung)),
          TextCellValue(therapeutText),
          TextCellValue(patient.name),
          TextCellValue(patient.vorname),
          TextCellValue(patient.adresse),
          TextCellValue(patient.telefon),
          TextCellValue(patient.versicherung),
          TextCellValue(patient.arzt),
          TextCellValue(patient.stoerungsbild),
          TextCellValue(patient.terminWunsch),
          TextCellValue(patient.weitereInfos),
        ]);
      }

      // Leerzeile
      sheet.appendRow([TextCellValue('')]);

      // Zusammenfassung
      final gesamt = monatPatienten.length;
      final platzGefunden = monatPatienten
          .where((p) => p.status == PatientStatus.platzGefunden)
          .length;
      final nochWartend = monatPatienten
          .where((p) => p.status == PatientStatus.wartend)
          .length;
      final auslastung = gesamt > 0
          ? ((platzGefunden / gesamt) * 100).toStringAsFixed(1)
          : '0.0';

      sheet.appendRow([
        TextCellValue('Gesamt:'),
        TextCellValue('$gesamt'),
      ]);
      sheet.appendRow([
        TextCellValue('Platz gefunden:'),
        TextCellValue('$platzGefunden'),
      ]);
      sheet.appendRow([
        TextCellValue('Noch wartend:'),
        TextCellValue('$nochWartend'),
      ]);
      sheet.appendRow([
        TextCellValue('Auslastung:'),
        TextCellValue('$auslastung%'),
      ]);
    }

    // Falls kein Sheet erstellt wurde, leeres Sheet erzeugen
    if (sortedMonths.isEmpty) {
      excel['Leer'].appendRow([TextCellValue('Keine Daten vorhanden')]);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Excel-Encoding fehlgeschlagen');
    }
    return encoded;
  }

  // ============================================================
  // Hilfsmethoden
  // ============================================================

  /// Konvertiert einen Zellenwert sicher zu einem String.
  String _cellToString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  /// Konvertiert einen Monat-Key ('yyyy-MM') in einen deutschen Sheet-Namen.
  ///
  /// z.B. '2024-03' -> 'März 2024'
  String _monatKeyToSheetName(String monatKey) {
    final parts = monatKey.split('-');
    if (parts.length != 2) return monatKey;

    final year = parts[0];
    final monthNum = int.tryParse(parts[1]);
    if (monthNum == null || monthNum < 1 || monthNum > 12) return monatKey;

    return '${_monate[monthNum - 1]} $year';
  }
}
