import 'package:cloud_firestore/cloud_firestore.dart';

class Praxis {
  final String id;
  final String name;
  final String inhaber;
  final String adresse;
  final String telefon;
  final String email;
  final DateTime createdAt;

  const Praxis({
    required this.id,
    required this.name,
    this.inhaber = '',
    this.adresse = '',
    this.telefon = '',
    this.email = '',
    required this.createdAt,
  });

  factory Praxis.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Praxis(
      id: doc.id,
      name: data['name'] as String? ?? '',
      inhaber: data['inhaber'] as String? ?? '',
      adresse: data['adresse'] as String? ?? '',
      telefon: data['telefon'] as String? ?? '',
      email: data['email'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'inhaber': inhaber,
      'adresse': adresse,
      'telefon': telefon,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Praxis copyWith({
    String? id,
    String? name,
    String? inhaber,
    String? adresse,
    String? telefon,
    String? email,
    DateTime? createdAt,
  }) {
    return Praxis(
      id: id ?? this.id,
      name: name ?? this.name,
      inhaber: inhaber ?? this.inhaber,
      adresse: adresse ?? this.adresse,
      telefon: telefon ?? this.telefon,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Praxis(id: $id, name: $name, inhaber: $inhaber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Praxis && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
