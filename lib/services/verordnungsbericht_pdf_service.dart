import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import '../models/praxis.dart';
import '../models/verordnungsbericht_data.dart';
import 'praxis_briefpapier.dart';

import 'pdf_platform_stub.dart'
    if (dart.library.html) 'pdf_platform_web.dart' as pdfPlatform;

/// Verordnungs-Bericht PDF — generiert via HTML + Browser-Print.
///
/// Kein dart-pdf-Paket, kein DataView-Decode-Problem. Stattdessen
/// rendert der Browser nativ HTML/CSS in A4-Format.
class VerordnungsberichtPdfService {
  static Future<void> drucken(
    VerordnungsberichtData data, {
    Praxis? praxis,
  }) async {
    final html = await _buildHtml(data, praxis: praxis);
    await pdfPlatform.openHtmlForPrint(html, _filename(data));
  }

  static Future<void> teilen(
    VerordnungsberichtData data, {
    Praxis? praxis,
  }) async {
    // Im Browser ist 'Drucken' identisch — User klickt im Print-Dialog
    // dann auf 'Speichern als PDF'.
    await drucken(data, praxis: praxis);
  }

  /// Generates a single HTML document for the Verordnungs-Bericht.
  static Future<String> _buildHtml(
    VerordnungsberichtData d, {
    Praxis? praxis,
  }) async {
    final briefpapier = await PraxisBriefpapierService.forPraxis(praxis);
    final fmt = DateFormat('dd.MM.yyyy');
    final logoSrc = await _logoDataUri();
    final accent = '#1A3FA0';

    String fmtOrDash(DateTime? d) => d != null ? fmt.format(d) : '';

    String cb(bool checked, [String suffix = '']) {
      final mark = checked ? '☒' : '☐';
      return suffix.isNotEmpty
          ? '$mark&nbsp;$suffix'
          : mark;
    }

    return '''
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<title>Verordnungs-Bericht — ${_esc(d.vorname)} ${_esc(d.name)}</title>
<style>
  @page { size: A4; margin: 10mm 12mm 8mm 12mm; }
  * { box-sizing: border-box; }
  html, body {
    margin: 0; padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    color: #000;
    font-size: 9.5pt;
    line-height: 1.3;
  }
  .briefkopf {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    margin-bottom: 6mm;
  }
  .briefkopf-text {
    color: $accent;
    font-size: 8.5pt;
    font-weight: bold;
    line-height: 1.3;
  }
  .briefkopf-text .adresse {
    font-weight: normal;
    font-size: 8pt;
  }
  .logo {
    max-width: 22mm;
    max-height: 22mm;
  }
  .form {
    border: 0.5pt solid #000;
    page-break-inside: avoid;
  }
  .banner {
    text-align: center;
    font-size: 12pt;
    font-weight: bold;
    padding: 2.5mm 0;
    border-bottom: 0.5pt solid #000;
  }
  .row {
    display: flex;
    border-bottom: 0.5pt solid #000;
  }
  .row:last-child { border-bottom: none; }
  .cell {
    flex: 1;
    padding: 2.5mm 3mm;
  }
  .cell.right { border-left: 0.5pt solid #000; }
  .cell-titel {
    font-weight: bold;
    font-size: 9.5pt;
    margin-bottom: 2mm;
  }
  .feld { margin-bottom: 2.5mm; }
  .feld-label {
    font-size: 9pt;
    color: #000;
    line-height: 1.2;
  }
  .feld-wert {
    border-bottom: 0.4pt solid #888;
    padding: 0.5mm 0;
    min-height: 4mm;
    font-size: 10pt;
  }
  .feld-bold .feld-label { font-weight: bold; }
  .empfehlungen {
    padding: 2.5mm 3mm;
    border-bottom: 0.5pt solid #000;
  }
  .empfehlungen-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1mm 6mm;
    margin-top: 1mm;
  }
  .check {
    font-size: 9.5pt;
    line-height: 1.45;
  }
  .check b { font-weight: bold; }
  .row-bottom .cell { min-height: 55mm; }
  .stempel-feld {
    margin-top: 0.5mm;
    font-size: 8pt;
    color: #555;
  }
  .stempel-name {
    font-weight: bold;
    font-size: 9.5pt;
    color: #000;
    margin-top: 0;
  }
  .unterschrift {
    margin-top: 14mm;
    border-top: 0.4pt solid #000;
    padding-top: 0.8mm;
  }
  .unterschrift .label-bold {
    font-weight: bold;
    font-size: 9.5pt;
  }
  .unterschrift .label-light {
    font-size: 8pt;
    color: #555;
  }
  .footer-note {
    margin-top: 3mm;
    font-size: 7.5pt;
    color: #555;
    line-height: 1.3;
  }
  .footer-note b { color: #000; }
  .footer-note .seitenzahl {
    text-align: right;
    margin-top: 0.5mm;
  }
  /* Print: ensure colors print + force single page */
  @media print {
    html, body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    .form, .briefkopf, .footer-note { page-break-inside: avoid; }
  }
</style>
</head>
<body>

<!-- Briefkopf -->
<div class="briefkopf">
  <div class="briefkopf-text">
    ${_esc(briefpapier.praxisName)}
    <div class="adresse">${_esc(briefpapier.standortAdresse)}</div>
  </div>
  ${logoSrc != null ? '<img class="logo" src="$logoSrc" alt="Logo">' : ''}
</div>

<!-- Verordnungs-Bericht Tabelle -->
<div class="form">
  <div class="banner">Verordnungs-Bericht</div>

  <!-- Reihe 1: Personalien | Verordnungsdatum/Diagnose -->
  <div class="row">
    <div class="cell">
      <div class="cell-titel">Personalien der oder des Versicherten</div>
      <div class="feld">
        <div class="feld-label">Name</div>
        <div class="feld-wert">${_esc(d.name)}</div>
      </div>
      <div class="feld">
        <div class="feld-label">Vorname</div>
        <div class="feld-wert">${_esc(d.vorname)}</div>
      </div>
      <div class="feld">
        <div class="feld-label">geb. am</div>
        <div class="feld-wert">${fmtOrDash(d.geburtsdatum)}</div>
      </div>
    </div>
    <div class="cell right">
      <div class="feld feld-bold">
        <div class="feld-label">Verordnungsdatum</div>
        <div class="feld-wert">${fmtOrDash(d.verordnungsdatum)}</div>
      </div>
      <div class="feld feld-bold">
        <div class="feld-label">Diagnosegruppe</div>
        <div class="feld-wert">${_esc(d.diagnosegruppe)}</div>
      </div>
      <div class="feld feld-bold">
        <div class="feld-label">Therapeutische Diagnose</div>
        <div class="feld-wert" style="min-height:14mm; line-height:1.4;">${_escMulti(d.therapeutischeDiagnose)}</div>
      </div>
    </div>
  </div>

  <!-- Reihe 2: Empfehlungen -->
  <div class="empfehlungen">
    <div class="cell-titel">Empfehlungen der Therapeutin oder des Therapeuten</div>
    <div class="empfehlungen-grid">
      <div class="check">${cb(d.empFortfuehrung)}&nbsp;Fortführung der Therapie</div>
      <div class="check">${cb(d.empEinzeltherapie)}&nbsp;Einzeltherapie&nbsp;&nbsp;Minuten ${d.empEinzeltherapieMinuten.isNotEmpty ? '<b>${_esc(d.empEinzeltherapieMinuten)}</b>' : '_____'}</div>

      <div class="check">${cb(d.empTherapiepause)}&nbsp;Therapiepause</div>
      <div class="check">${cb(d.empGruppentherapie)}&nbsp;Gruppentherapie Minuten ${d.empGruppentherapieMinuten.isNotEmpty ? '<b>${_esc(d.empGruppentherapieMinuten)}</b>' : '_____'}</div>

      <div class="check">${cb(d.empBeendigung)}&nbsp;Beendigung der Therapie</div>
      <div class="check">${cb(d.empDoppelbehandlung)}&nbsp;Doppelbehandlung</div>

      <div class="check">${cb(d.empWiedervorstellung)}&nbsp;Wiedervorstellung ${d.empWiedervorstellungText.isNotEmpty ? '<b>${_esc(d.empWiedervorstellungText)}</b>' : '_____'}</div>
      <div class="check">${cb(d.empFrequenz)}&nbsp;Frequenz&nbsp;&nbsp;Anzahl/Woche ${d.empFrequenzText.isNotEmpty ? '<b>${_esc(d.empFrequenzText)}</b>' : '_____'}</div>

      <div class="check">${cb(d.empAndereTherapie)}&nbsp;andere Therapie ${d.empAndereTherapieText.isNotEmpty ? '<b>${_esc(d.empAndereTherapieText)}</b>' : '_____'}</div>
      <div class="check">${cb(d.empHausbesuch)}&nbsp;Hausbesuch</div>
    </div>
  </div>

  <!-- Reihe 3: Zusammenfassung | Datum/Stempel -->
  <div class="row row-bottom">
    <div class="cell">
      <div class="cell-titel">Zusammenfassung Therapieverlauf,<br>ggf. Begründung zur Empfehlung</div>
      <div style="margin-top:3mm; white-space:pre-wrap; font-size:10.5pt; line-height:1.5;">${_escMulti(d.zusammenfassung)}</div>
    </div>
    <div class="cell right">
      <div class="feld feld-bold">
        <div class="feld-label">Datum</div>
        <div class="feld-wert">${fmtOrDash(d.datum)}</div>
      </div>
      <div class="stempel-name">Praxisstempel oder Adressdaten,</div>
      <div class="stempel-feld">wenn nicht im Briefkopf</div>
      <div class="unterschrift">
        <div class="label-bold">Unterschrift Therapeutin / Therapeut,</div>
        <div class="label-light">wenn nicht digital versendet</div>
      </div>
    </div>
  </div>
</div>

<!-- Footer-Note -->
<div class="footer-note">
  Anhang A zu Anlage 1 zum Vertrag nach § 125 Absatz 1 SGB V: <b>Verordnungs-Bericht</b><br>
  Bericht gemäß § 13 Absatz 2 lit. d, § 16 Absatz 7 HeilM-RL / § 11 Absatz 2 lit. c, § 15 Absatz 5 HeilM-RL ZÄ
  <div class="seitenzahl">Seite 1 von 1</div>
</div>

<script>
  // Auto-Print sobald Logo (falls vorhanden) geladen ist
  window.addEventListener('load', function() {
    setTimeout(function() { window.print(); }, 350);
  });
</script>

</body>
</html>
''';
  }

  static Future<String?> _logoDataUri() async {
    try {
      final data = await rootBundle.load('assets/praxis_logos/menauer.png');
      final bytes = data.buffer.asUint8List();
      return 'data:image/png;base64,${base64Encode(bytes)}';
    } catch (_) {
      try {
        final data =
            await rootBundle.load('assets/praxis_logos/menauer.jpg');
        final bytes = data.buffer.asUint8List();
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (_) {
        return null;
      }
    }
  }

  static String _esc(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _escMulti(String s) {
    return _esc(s).replaceAll('\n', '<br>');
  }

  static String _filename(VerordnungsberichtData d) {
    final fmt = DateFormat('yyyy-MM-dd');
    final datum = d.datum ?? DateTime.now();
    final patientPart =
        '${d.name} ${d.vorname}'.trim().replaceAll(RegExp(r'\s+'), ' ');
    final clean =
        patientPart.replaceAll(RegExp(r'[^\w\säöüÄÖÜß-]'), '').trim();
    return 'Verordnungsbericht ${fmt.format(datum)}'
        '${clean.isNotEmpty ? " - $clean" : ""}.pdf';
  }

  // ── Legacy buildPdf-Stub (für alten Aufrufpfad, falls noch nötig) ──
  static Future<Uint8List> buildPdf(
    VerordnungsberichtData data, {
    Praxis? praxis,
  }) async {
    // Wir generieren kein PDF mehr direkt — der Aufrufer sollte stattdessen
    // drucken() oder teilen() verwenden.
    return Uint8List(0);
  }
}
