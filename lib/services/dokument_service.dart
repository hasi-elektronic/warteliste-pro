import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/dokument.dart';

// Conditional import fuer Web vs Mobile HTTP
import 'r2_uploader_stub.dart'
    if (dart.library.html) 'r2_uploader_web.dart' as uploader;

/// Service fuer Dokument-Upload (Cloudflare R2) und Verwaltung (Firestore).
class DokumentService {
  static const r2Base = 'https://warteliste-pro-r2.hguencavdi.workers.dev';

  final FirebaseFirestore _firestore;

  DokumentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _dokumenteRef(
    String praxisId,
    String patientId,
  ) =>
      _firestore
          .collection('praxen')
          .doc(praxisId)
          .collection('patienten')
          .doc(patientId)
          .collection('dokumente');

  /// Laedt ein Dokument hoch (R2) und erstellt einen Firestore-Eintrag.
  Future<Dokument> uploadDokument({
    required Uint8List bytes,
    required String fileName,
    required String patientId,
    required String praxisId,
    required DokumentTyp typ,
  }) async {
    final uuid = const Uuid().v4();
    final ext = fileName.contains('.')
        ? fileName.split('.').last
        : (typ == DokumentTyp.pdf ? 'pdf' : 'jpg');
    final key = 'praxen/$praxisId/patienten/$patientId/$uuid.$ext';
    final contentType =
        typ == DokumentTyp.pdf ? 'application/pdf' : 'image/jpeg';

    // Firebase ID Token fuer Auth beim R2-Worker
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw Exception('Nicht angemeldet');
    }

    // R2 Upload
    final url = await uploader.uploadToR2(
      baseUrl: r2Base,
      key: key,
      bytes: bytes,
      contentType: contentType,
      idToken: idToken,
    );

    // Firestore-Eintrag
    final dokument = Dokument(
      id: '',
      patientId: patientId,
      praxisId: praxisId,
      name: fileName,
      url: url,
      typ: typ,
      erstelltAm: DateTime.now(),
      groesseBytes: bytes.length,
    );

    final docRef =
        await _dokumenteRef(praxisId, patientId).add(dokument.toFirestore());

    return Dokument(
      id: docRef.id,
      patientId: patientId,
      praxisId: praxisId,
      name: fileName,
      url: url,
      typ: typ,
      erstelltAm: dokument.erstelltAm,
      groesseBytes: bytes.length,
    );
  }

  /// Echtzeit-Stream aller Dokumente eines Patienten.
  Stream<List<Dokument>> getDokumente(String praxisId, String patientId) {
    return _dokumenteRef(praxisId, patientId)
        .orderBy('erstelltAm', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Dokument.fromFirestore(d)).toList());
  }

  /// Loescht ein Dokument (R2 + Firestore).
  Future<void> deleteDokument({
    required String praxisId,
    required String patientId,
    required String dokumentId,
    required String url,
  }) async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken != null) {
        await uploader.deleteFromR2(url: url, baseUrl: r2Base, idToken: idToken);
      }
    } catch (_) {}
    await _dokumenteRef(praxisId, patientId).doc(dokumentId).delete();
  }
}
