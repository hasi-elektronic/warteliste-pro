import 'package:cloud_firestore/cloud_firestore.dart';

/// Ein Arzt im Praxis-Adressbuch (wiederverwendbar über mehrere Patienten
/// und Briefe hinweg).
///
/// Firestore-Pfad: `/praxen/{praxisId}/aerzte/{id}`
class Arzt {
  final String id;
  final String name;
  final String strasse;
  final String plz;
  final String ort;
  final String telefon;
  final String fachrichtung;
  final bool aktiv;
  final String praxisId;

  const Arzt({
    required this.id,
    required this.name,
    this.strasse = '',
    this.plz = '',
    this.ort = '',
    this.telefon = '',
    this.fachrichtung = '',
    this.aktiv = true,
    required this.praxisId,
  });

  /// Formatierter Adressblock für Briefe (mehrzeilig, leere Felder entfallen).
  String get adressBlock {
    final zeilen = <String>[];
    if (name.trim().isNotEmpty) zeilen.add(name.trim());
    if (strasse.trim().isNotEmpty) zeilen.add(strasse.trim());
    final plzOrt =
        [plz.trim(), ort.trim()].where((e) => e.isNotEmpty).join(' ');
    if (plzOrt.isNotEmpty) zeilen.add(plzOrt);
    return zeilen.join('\n');
  }

  /// Kurzbeschreibung für Listen/Picker: "Name — Ort" bzw. "Name".
  String get anzeigeZeile {
    final teile = <String>[if (name.trim().isNotEmpty) name.trim()];
    if (ort.trim().isNotEmpty) teile.add(ort.trim());
    return teile.join(' — ');
  }

  factory Arzt.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Arzt(
      id: doc.id,
      name: data['name'] as String? ?? '',
      strasse: data['strasse'] as String? ?? '',
      plz: data['plz'] as String? ?? '',
      ort: data['ort'] as String? ?? '',
      telefon: data['telefon'] as String? ?? '',
      fachrichtung: data['fachrichtung'] as String? ?? '',
      aktiv: data['aktiv'] as bool? ?? true,
      praxisId: data['praxisId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'strasse': strasse,
      'plz': plz,
      'ort': ort,
      'telefon': telefon,
      'fachrichtung': fachrichtung,
      'aktiv': aktiv,
      'praxisId': praxisId,
    };
  }

  Arzt copyWith({
    String? id,
    String? name,
    String? strasse,
    String? plz,
    String? ort,
    String? telefon,
    String? fachrichtung,
    bool? aktiv,
    String? praxisId,
  }) {
    return Arzt(
      id: id ?? this.id,
      name: name ?? this.name,
      strasse: strasse ?? this.strasse,
      plz: plz ?? this.plz,
      ort: ort ?? this.ort,
      telefon: telefon ?? this.telefon,
      fachrichtung: fachrichtung ?? this.fachrichtung,
      aktiv: aktiv ?? this.aktiv,
      praxisId: praxisId ?? this.praxisId,
    );
  }

  @override
  String toString() => 'Arzt(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Arzt && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
