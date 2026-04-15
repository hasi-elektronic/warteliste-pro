import 'package:cloud_firestore/cloud_firestore.dart';

class Therapeut {
  final String id;
  final String name;
  final bool aktiv;
  final String praxisId;
  final int maxPatienten; // 0 = unbegrenzt
  final String? fachgebiet;

  const Therapeut({
    required this.id,
    required this.name,
    this.aktiv = true,
    required this.praxisId,
    this.maxPatienten = 0,
    this.fachgebiet,
  });

  factory Therapeut.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Therapeut(
      id: doc.id,
      name: data['name'] as String? ?? '',
      aktiv: data['aktiv'] as bool? ?? true,
      praxisId: data['praxisId'] as String? ?? '',
      maxPatienten: data['maxPatienten'] as int? ?? 0,
      fachgebiet: data['fachgebiet'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'aktiv': aktiv,
      'praxisId': praxisId,
      'maxPatienten': maxPatienten,
      'fachgebiet': fachgebiet,
    };
  }

  Therapeut copyWith({
    String? id,
    String? name,
    bool? aktiv,
    String? praxisId,
    int? maxPatienten,
    String? fachgebiet,
    bool clearFachgebiet = false,
  }) {
    return Therapeut(
      id: id ?? this.id,
      name: name ?? this.name,
      aktiv: aktiv ?? this.aktiv,
      praxisId: praxisId ?? this.praxisId,
      maxPatienten: maxPatienten ?? this.maxPatienten,
      fachgebiet: clearFachgebiet ? null : (fachgebiet ?? this.fachgebiet),
    );
  }

  @override
  String toString() => 'Therapeut(id: $id, name: $name, aktiv: $aktiv)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Therapeut && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
