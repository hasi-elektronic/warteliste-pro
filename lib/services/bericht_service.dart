import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bericht.dart';

/// CRUD fuer Berichte (praxen/{praxisId}/berichte/{id}).
class BerichtService {
  final FirebaseFirestore _firestore;

  BerichtService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String praxisId) => _firestore
      .collection('praxen')
      .doc(praxisId)
      .collection('berichte');

  /// Alle Berichte einer Praxis (chronologisch absteigend).
  Stream<List<Bericht>> getBerichte(String praxisId) {
    return _ref(praxisId)
        .orderBy('erstelltAm', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Bericht.fromFirestore(d)).toList());
  }

  /// Berichte zu einem bestimmten Patienten.
  Stream<List<Bericht>> getBerichteFuerPatient(
      String praxisId, String patientId) {
    return _ref(praxisId)
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Bericht.fromFirestore(d)).toList();
      list.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));
      return list;
    });
  }

  Future<String> addBericht(Bericht bericht) async {
    final doc = await _ref(bericht.praxisId).add(bericht.toFirestore());
    return doc.id;
  }

  Future<void> updateBericht(Bericht bericht) async {
    final data = bericht.toFirestore();
    data['aktualisiertAm'] = Timestamp.now();
    await _ref(bericht.praxisId).doc(bericht.id).update(data);
  }

  Future<void> deleteBericht(String praxisId, String id) async {
    await _ref(praxisId).doc(id).delete();
  }
}
