import 'package:flutter_test/flutter_test.dart';
import 'package:warteliste_pro/models/patient.dart';

Patient _p({String arzt = '', String strasse = '', String plz = '', String ort = ''}) {
  return Patient(
    id: 'x',
    anmeldung: DateTime(2026, 1, 1),
    name: 'Muster',
    vorname: 'Max',
    monat: '2026-01',
    praxisId: 'praxis1',
    arzt: arzt,
    arztStrasse: strasse,
    arztPlz: plz,
    arztOrt: ort,
  );
}

void main() {
  group('Patient Arzt-Adresse', () {
    test('leer, wenn keine Arzt-Daten', () {
      final p = _p();
      expect(p.hatArztAdresse, isFalse);
      expect(p.arztAdressBlock, '');
    });

    test('vollstaendiger Adressblock, mehrzeilig', () {
      final p = _p(
        arzt: 'Dr. med. Anna Weber',
        strasse: 'Hauptstraße 1',
        plz: '71665',
        ort: 'Vaihingen',
      );
      expect(p.hatArztAdresse, isTrue);
      expect(
        p.arztAdressBlock,
        'Dr. med. Anna Weber\nHauptstraße 1\n71665 Vaihingen',
      );
    });

    test('nur Name reicht fuer hatArztAdresse', () {
      final p = _p(arzt: 'Dr. Weber');
      expect(p.hatArztAdresse, isTrue);
      expect(p.arztAdressBlock, 'Dr. Weber');
    });

    test('PLZ und Ort werden in einer Zeile kombiniert', () {
      final p = _p(plz: '71665', ort: 'Vaihingen');
      expect(p.arztAdressBlock, '71665 Vaihingen');
    });

    test('Felder ueberleben Firestore-Roundtrip nicht noetig — copyWith behaelt sie', () {
      final p = _p(arzt: 'Dr. Weber', strasse: 'Weg 2', plz: '70000', ort: 'Stuttgart');
      final kopie = p.copyWith(name: 'Neu');
      expect(kopie.arzt, 'Dr. Weber');
      expect(kopie.arztStrasse, 'Weg 2');
      expect(kopie.arztPlz, '70000');
      expect(kopie.arztOrt, 'Stuttgart');
    });
  });
}
