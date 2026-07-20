import 'package:flutter_test/flutter_test.dart';
import 'package:warteliste_pro/models/arzt.dart';

void main() {
  test('adressBlock ist mehrzeilig und laesst leere Felder aus', () {
    const a = Arzt(
      id: '1', praxisId: 'p', name: 'Dr. Weber',
      strasse: 'Weg 2', plz: '71665', ort: 'Vaihingen',
    );
    expect(a.adressBlock, 'Dr. Weber\nWeg 2\n71665 Vaihingen');
  });

  test('adressBlock nur mit Name', () {
    const a = Arzt(id: '1', praxisId: 'p', name: 'Dr. Weber');
    expect(a.adressBlock, 'Dr. Weber');
  });

  test('anzeigeZeile kombiniert Name und Ort', () {
    const a = Arzt(id: '1', praxisId: 'p', name: 'Dr. Weber', ort: 'Stuttgart');
    expect(a.anzeigeZeile, 'Dr. Weber — Stuttgart');
  });

  test('copyWith behaelt Felder', () {
    const a = Arzt(id: '1', praxisId: 'p', name: 'Dr. Weber', plz: '70000');
    final b = a.copyWith(name: 'Dr. Neu');
    expect(b.name, 'Dr. Neu');
    expect(b.plz, '70000');
  });
}
