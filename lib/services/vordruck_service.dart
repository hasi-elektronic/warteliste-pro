import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/praxis.dart';
import '../models/vordruck.dart';
import '../utils/theme.dart';

// Conditional import — Web blob, Mobile printing.
import 'pdf_platform_stub.dart'
    if (dart.library.html) 'pdf_platform_web.dart' as pdfPlatform;

/// Liefert die Liste der verfügbaren Vordrucke + Lade-/Druck-/Share-Funktionen.
class VordruckService {
  // ── Verfuegbare Vordrucke (Reihenfolge = UI-Reihenfolge) ───────
  static final List<Vordruck> all = [
    // ── Therapieberichte ─────────────────────────────────────────
    Vordruck(
      id: 'verordnungsbericht_menauer',
      titel: 'Verordnungs-Bericht',
      beschreibung:
          'Mit Praxis-Briefkopf — direkt im App ausfüllen oder Original laden',
      gruppe: 'Therapieberichte',
      icon: Icons.assignment_outlined,
      color: Color(0xFF1A3FA0),
      sichtbarFuerPraxisStichwort: 'menauer',
      standortVarianten: {
        'ditzingen':
            'assets/vordrucke/menauer/verordnungsbericht_ditzingen.pdf',
        'vaihingen':
            'assets/vordrucke/menauer/verordnungsbericht_vaihingen.pdf',
        '': 'assets/vordrucke/menauer/verordnungsbericht_weil.pdf',
      },
      ausfuellenRoute: '/verordnungsbericht/neu',
    ),
    Vordruck(
      id: 'verordnungsbericht_blanko',
      titel: 'Verordnungs-Bericht (Blanko)',
      beschreibung:
          'Standard-Anhang A zu § 125 SGB V — direkt ausfüllen oder leer drucken',
      gruppe: 'Therapieberichte',
      icon: Icons.description_outlined,
      color: AppTheme.slate600,
      assetPfad: 'assets/vordrucke/verordnungsbericht_blanko.pdf',
      ausfuellenRoute: '/verordnungsbericht/neu',
    ),
    Vordruck(
      id: 'langbericht',
      titel: 'Langbericht (Word)',
      beschreibung:
          'Ausführlicher Bericht mit Diagnostik, Behandlung, Prognose — '
          'editierbar in Microsoft Word',
      gruppe: 'Therapieberichte',
      icon: Icons.article_outlined,
      color: Color(0xFF2563EB),
      assetPfad: 'assets/vordrucke/langbericht.docx',
      erweiterung: 'docx',
    ),

    // ── Anforderungen ────────────────────────────────────────────
    Vordruck(
      id: 'anforderung_bericht',
      titel: 'Anforderung Bericht',
      beschreibung:
          'Anforderung durch Ärztin/Arzt oder Medizinischen Dienst — '
          'Anhang B zu § 125 SGB V',
      gruppe: 'Anforderungen',
      icon: Icons.mark_email_read_outlined,
      color: AppTheme.warningColor,
      assetPfad: 'assets/vordrucke/anforderung_bericht.pdf',
    ),

    // ── Befundberichte (Weil der Stadt) ──────────────────────────
    Vordruck(
      id: 'weil_befund_avws',
      titel: 'Befund: AVWS',
      beschreibung:
          'Logopädischer Befundbericht — Auditive Verarbeitungs- und Wahrnehmungsstörung',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_avws.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_dysarthrie',
      titel: 'Befund: Dysarthrie',
      beschreibung:
          'Logopädischer Befundbericht — Dysarthrie',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_dysarthrie.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_dysgrammatismus',
      titel: 'Befund: Dysgrammatismus',
      beschreibung:
          'Logopädischer Befundbericht — Dysgrammatismus',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_dysgrammatismus.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_dysphagie',
      titel: 'Befund: Dysphagie',
      beschreibung:
          'Logopädischer Befundbericht — Schluckstörung',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_dysphagie.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_facialis',
      titel: 'Befund: Fazialisparese',
      beschreibung:
          'Logopädischer Befundbericht — Fazialisparese',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_facialis.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_mfs',
      titel: 'Befund: Myofunktionelle Störung',
      beschreibung:
          'Logopädischer Befundbericht — MFS',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_mfs.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_phonologie',
      titel: 'Befund: Phonologische Störung',
      beschreibung:
          'Logopädischer Befundbericht — Phonologie',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_phonologie.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_ses',
      titel: 'Befund: SES',
      beschreibung:
          'Logopädischer Befundbericht — Sprachentwicklungsstörung',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_ses.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_stimme',
      titel: 'Befund: Stimmstörung',
      beschreibung:
          'Logopädischer Befundbericht — Stimme',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_stimme.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befund_stottern',
      titel: 'Befund: Stottern',
      beschreibung:
          'Logopädischer Befundbericht — Redeflussstörung',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befund_stottern.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befundbericht_dysphagie',
      titel: 'Befundbericht: Dysphagie',
      beschreibung:
          'Ausführlicher Befundbericht — Schluckstörung',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befundbericht_dysphagie.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_befundvorlage',
      titel: 'Befundvorlage (allgemein)',
      beschreibung:
          'Leere Befund-Grundvorlage zum freien Ausfüllen',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/befundvorlage.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_dyslalie_befund',
      titel: 'Befund: Dyslalie',
      beschreibung:
          'Logopädischer Befundbericht — Dyslalie',
      gruppe: 'Befundberichte (Weil der Stadt)',
      icon: Icons.assignment_outlined,
      color: Color(0xFF0F766E),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/dyslalie_befund.doc',
      erweiterung: 'doc',
    ),

    // ── Mitteilungen an den Arzt (Weil der Stadt) ────────────────
    Vordruck(
      id: 'weil_mitteilung_avws',
      titel: 'Mitteilung an Arzt: AVWS',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — AVWS',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_avws.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_aphasie',
      titel: 'Mitteilung an Arzt: Aphasie',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — Aphasie',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_aphasie.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_dysarthrie',
      titel: 'Mitteilung an Arzt: Dysarthrie',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — Dysarthrie',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_dysarthrie.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_dyslalie',
      titel: 'Mitteilung an Arzt: Dyslalie',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — Dyslalie',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_dyslalie.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_dyslalie_2',
      titel: 'Mitteilung an Arzt: Dyslalie (Variante 2)',
      beschreibung:
          'Alternative Kurzmitteilung — Dyslalie',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_dyslalie_2.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_dysphagie',
      titel: 'Mitteilung an Arzt: Dysphagie',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — Dysphagie',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_dysphagie.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_facialis',
      titel: 'Mitteilung an Arzt: Fazialisparese',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — Fazialisparese',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_facialis.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_myo',
      titel: 'Mitteilung an Arzt: Myofunktionelle Störung',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — MFS',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_myo.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_ses',
      titel: 'Mitteilung an Arzt: SES',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — SES',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_ses.doc',
      erweiterung: 'doc',
    ),
    Vordruck(
      id: 'weil_mitteilung_sprachentwicklungsstoerung',
      titel: 'Mitteilung an Arzt: Sprachentwicklungsstörung',
      beschreibung:
          'Kurzmitteilung an die verordnende Ärztin/den Arzt — SES',
      gruppe: 'Mitteilungen an den Arzt (Weil der Stadt)',
      icon: Icons.mail_outline,
      color: Color(0xFF2563EB),
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/mitteilung_sprachentwicklungsstoerung.doc',
      erweiterung: 'doc',
    ),

    // ── Briefpapier (Weil der Stadt) ─────────────────────────────
    Vordruck(
      id: 'weil_briefpapier_wds',
      titel: 'Briefpapier Weil der Stadt',
      beschreibung:
          'Leeres Praxis-Briefpapier zum freien Beschriften',
      gruppe: 'Briefpapier (Weil der Stadt)',
      icon: Icons.description_outlined,
      color: AppTheme.slate600,
      sichtbarFuerPraxisStichwort: 'weil',
      assetPfad: 'assets/vordrucke/menauer/weil/briefpapier_wds.doc',
      erweiterung: 'doc',
    ),
  ];

  /// Sichtbare Vordrucke für die aktuelle Praxis.
  static List<Vordruck> visibleFor(Praxis? praxis) {
    final praxisName = praxis?.name.toLowerCase() ?? '';
    // Demo-/Test-Standorte sehen ALLE Vordrucke — so kann man den
    // Vorlagen→Bericht-Ablauf gefahrlos testen, ohne echte Daten zu
    // beruehren.
    final istTestStandort =
        praxisName.contains('demo') || praxisName.contains('test');
    return all.where((v) {
      if (v.sichtbarFuerPraxisStichwort == null) return true;
      if (istTestStandort) return true;
      return praxisName.contains(v.sichtbarFuerPraxisStichwort!);
    }).toList();
  }

  /// Wählt den richtigen Asset-Pfad — bei standortspezifischen Vordrucken
  /// anhand des Praxis-Namens, sonst direkt assetPfad.
  static String _resolvePath(Vordruck v, Praxis? praxis) {
    if (v.assetPfad != null) return v.assetPfad!;
    final varianten = v.standortVarianten;
    if (varianten == null || varianten.isEmpty) {
      throw Exception('Vordruck "${v.titel}" hat keinen Pfad');
    }
    final name = praxis?.name.toLowerCase() ?? '';
    for (final entry in varianten.entries) {
      if (entry.key.isNotEmpty && name.contains(entry.key)) {
        return entry.value;
      }
    }
    // Default: leerer Schluessel
    return varianten[''] ?? varianten.values.first;
  }

  static Future<Uint8List> _loadBytes(Vordruck v, Praxis? praxis) async {
    final path = _resolvePath(v, praxis);
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  static String _filenameFor(Vordruck v, Praxis? praxis) {
    final name = praxis?.name ?? '';
    final cleanName = name.replaceAll(RegExp(r'[^\w\säöüÄÖÜß-]'), '').trim();
    final base = [
      v.titel,
      if (cleanName.isNotEmpty) cleanName,
    ].join(' - ');
    return '$base.${v.erweiterung}';
  }

  /// Im Browser/Mobile öffnen (PDF-Vorschau / Print).
  /// DOCX wird als Download geliefert (kein nativer Viewer).
  static Future<void> drucken(Vordruck v, Praxis? praxis) async {
    final bytes = await _loadBytes(v, praxis);
    final filename = _filenameFor(v, praxis);
    if (v.istWord) {
      // Word-Dokumente (doc/docx) werden heruntergeladen statt gedruckt
      await pdfPlatform.sharePdf(bytes, filename);
    } else {
      await pdfPlatform.showPdf(bytes, filename);
    }
  }

  /// Datei herunterladen / teilen.
  static Future<void> teilen(Vordruck v, Praxis? praxis) async {
    final bytes = await _loadBytes(v, praxis);
    final filename = _filenameFor(v, praxis);
    await pdfPlatform.sharePdf(bytes, filename);
  }
}
