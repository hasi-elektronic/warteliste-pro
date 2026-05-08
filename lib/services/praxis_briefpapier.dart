import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../models/praxis.dart';

/// Daten fuer das Briefpapier eines Standorts (PDF-Footer + Logo).
class PraxisBriefpapier {
  final Uint8List? logoBytes;
  final String praxisName;       // z.B. "Logopädie-Praxis Susanne Menauer"
  final String standortAdresse;  // z.B. "Stuttgarter Str. 51, 71263 Weil der Stadt"
  final String standortTelefon;  // "(07033) 137724"
  final String? standortFax;
  final List<PraxisFooterBlock> footerBloecke;
  final String? website;

  const PraxisBriefpapier({
    this.logoBytes,
    required this.praxisName,
    required this.standortAdresse,
    required this.standortTelefon,
    this.standortFax,
    this.footerBloecke = const [],
    this.website,
  });
}

class PraxisFooterBlock {
  final String titel;
  final List<String> zeilen;
  const PraxisFooterBlock({required this.titel, required this.zeilen});
}

/// Lädt Briefpapier-Daten passend zur Praxis.
class PraxisBriefpapierService {
  /// Liefert Briefpapier-Daten anhand der Praxis (Erkennung ueber Name/Adresse).
  static Future<PraxisBriefpapier> forPraxis(Praxis? praxis) async {
    final name = praxis?.name.toLowerCase() ?? '';
    final adresse = praxis?.adresse.toLowerCase() ?? '';

    // ── Logopädie-Praxis Susanne Menauer ──
    if (name.contains('menauer') || adresse.contains('menauer')) {
      Uint8List? logo;
      try {
        // PNG bevorzugt — pdf-Paket hat manchmal Probleme mit bestimmten
        // JPEG-Codes ('Offset is outside the bounds of the DataView')
        final data =
            await rootBundle.load('assets/praxis_logos/menauer.png');
        logo = data.buffer.asUint8List();
      } catch (_) {
        try {
          final data =
              await rootBundle.load('assets/praxis_logos/menauer.jpg');
          logo = data.buffer.asUint8List();
        } catch (_) {/* fallback ohne Logo */}
      }

      // Standort-spezifische Adresse + Telefon
      String standortAdresse;
      String standortTelefon;
      String? standortFax;

      if (name.contains('ditzingen') || adresse.contains('ditzingen')) {
        standortAdresse = 'Marktstraße 6/1, 71254 Ditzingen';
        standortTelefon = '(07156) 1773574';
        standortFax = '(07156) 1773576';
      } else if (name.contains('vaihingen') || adresse.contains('vaihingen')) {
        standortAdresse = 'Andreaestr. 16/1, 71665 Vaihingen';
        standortTelefon = '(07042) 8187767';
        standortFax = '(07042) 3768-634';
      } else {
        // Default: Weil der Stadt
        standortAdresse = 'Stuttgarter Str. 51, 71263 Weil der Stadt';
        standortTelefon = '(07033) 137724';
        standortFax = '(07033) 137725';
      }

      return PraxisBriefpapier(
        logoBytes: logo,
        praxisName: 'Logopädie-Praxis Susanne Menauer',
        standortAdresse: standortAdresse,
        standortTelefon: standortTelefon,
        standortFax: standortFax,
        website: 'www.logo-menauer.de',
        footerBloecke: const [
          PraxisFooterBlock(
            titel: 'Verwaltung',
            zeilen: [
              'Winzerstraße 1/1',
              '71665 Vaihingen',
              'Tel. (07042) 8152600',
              'Fax (07042) 8152617',
            ],
          ),
          PraxisFooterBlock(
            titel: 'Praxis Weil der Stadt',
            zeilen: [
              '— im Spital —',
              'Stuttgarter Str. 51',
              '71263 Weil der Stadt',
              'Tel. (07033) 137724',
              'Fax (07033) 137725',
            ],
          ),
          PraxisFooterBlock(
            titel: 'Praxis Ditzingen',
            zeilen: [
              '— im Weißen Haus —',
              'Marktstraße 6/1',
              '71254 Ditzingen',
              'Tel. (07156) 1773574',
              'Fax (07156) 1773576',
            ],
          ),
          PraxisFooterBlock(
            titel: 'Praxis Vaihingen',
            zeilen: [
              '— im VaiSana —',
              'Andreaestr. 16/1',
              '71665 Vaihingen',
              'Tel. (07042) 8187767',
              'Fax (07042) 3768-634',
            ],
          ),
          PraxisFooterBlock(
            titel: 'Bankverbindung',
            zeilen: [
              'Kreissparkasse Ludwigsburg',
              'BIC: SOLADES1LBG',
              'IBAN Weil der Stadt',
              'DE65 6045 0050 0030 0845 91',
              'IBAN Ditzingen',
              'DE86 6045 0050 0030 0846 01',
              'IBAN Vaihingen',
              'DE15 6045 0050 0030 0846 18',
            ],
          ),
        ],
      );
    }

    // ── Generischer Fallback (andere Kunden) ──
    return PraxisBriefpapier(
      praxisName: praxis?.name ?? 'Praxis',
      standortAdresse: praxis?.adresse ?? '',
      standortTelefon: praxis?.telefon ?? '',
    );
  }
}
