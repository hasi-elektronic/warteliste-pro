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
  ];

  /// Sichtbare Vordrucke für die aktuelle Praxis.
  static List<Vordruck> visibleFor(Praxis? praxis) {
    final praxisName = praxis?.name.toLowerCase() ?? '';
    return all.where((v) {
      if (v.sichtbarFuerPraxisStichwort == null) return true;
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
    if (v.erweiterung == 'docx') {
      // Word-Dokumente werden heruntergeladen statt gedruckt
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
