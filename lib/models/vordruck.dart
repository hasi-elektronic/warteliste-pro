import 'package:flutter/material.dart';

/// Eine offizielle Vordruck-Vorlage (PDF/DOCX) — wird als Asset geliefert
/// und vom User unverändert heruntergeladen oder gedruckt.
class Vordruck {
  /// Eindeutige Kennung
  final String id;

  /// Anzeigename (z.B. "Verordnungs-Bericht")
  final String titel;

  /// Kurzbeschreibung
  final String beschreibung;

  /// Gruppe (z.B. "Therapieberichte", "Sonstiges")
  final String gruppe;

  /// Material Icon
  final IconData icon;

  /// Akzentfarbe für die Karte
  final Color color;

  /// Asset-Pfad zur Original-Datei. Falls [standortVarianten] gesetzt ist,
  /// wird automatisch die passende Variante gewählt.
  final String? assetPfad;

  /// Wenn true: aus [standortVarianten] wird der Pfad zur aktiven
  /// Praxis bestimmt (Schlüssel: lowercase praxis-name-substring → asset-pfad).
  final Map<String, String>? standortVarianten;

  /// Praxisspezifisch: nur sichtbar wenn der Praxis-Name das Stichwort enthält.
  /// (Bsp: nur Menauer-Praxen sehen die personalisierten Vordrucke)
  final String? sichtbarFuerPraxisStichwort;

  /// Dateierweiterung (pdf, docx)
  final String erweiterung;

  /// Wenn gesetzt: zeigt einen 'Ausfüllen'-Button, der zu dieser Route
  /// navigiert. Bsp: '/verordnungsbericht/neu'
  final String? ausfuellenRoute;

  /// MIME für Download/Share
  String get mimeType {
    switch (erweiterung) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  const Vordruck({
    required this.id,
    required this.titel,
    required this.beschreibung,
    required this.gruppe,
    required this.icon,
    required this.color,
    this.assetPfad,
    this.standortVarianten,
    this.sichtbarFuerPraxisStichwort,
    this.erweiterung = 'pdf',
    this.ausfuellenRoute,
  });
}
