import 'package:cloud_firestore/cloud_firestore.dart';

class Termin {
  final String id;
  final String patientId;
  final String therapeutId;
  final DateTime datum;
  final String notiz;
  final String praxisId;

  const Termin({
    required this.id,
    required this.patientId,
    required this.therapeutId,
    required this.datum,
    this.notiz = '',
    required this.praxisId,
  });

  factory Termin.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Termin(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      therapeutId: data['therapeutId'] as String? ?? '',
      datum: (data['datum'] as Timestamp).toDate(),
      notiz: data['notiz'] as String? ?? '',
      praxisId: data['praxisId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'therapeutId': therapeutId,
      'datum': Timestamp.fromDate(datum),
      'notiz': notiz,
      'praxisId': praxisId,
    };
  }

  Termin copyWith({
    String? id,
    String? patientId,
    String? therapeutId,
    DateTime? datum,
    String? notiz,
    String? praxisId,
  }) {
    return Termin(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      therapeutId: therapeutId ?? this.therapeutId,
      datum: datum ?? this.datum,
      notiz: notiz ?? this.notiz,
      praxisId: praxisId ?? this.praxisId,
    );
  }

  @override
  String toString() =>
      'Termin(id: $id, patientId: $patientId, datum: $datum)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Termin && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
