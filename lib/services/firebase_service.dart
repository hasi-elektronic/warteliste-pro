import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/patient.dart';
import '../models/patient_note.dart';
import '../models/praxis.dart';
import '../models/therapeut.dart';
import '../models/termin.dart';
import '../utils/constants.dart';

/// Zentraler Service fuer alle Firestore- und Auth-Operationen.
class FirebaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Gecachte Praxis-ID des aktuell eingeloggten Nutzers.
  String? _cachedPraxisId;

  FirebaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ============================================================
  // Collection References
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(AppConstants.collectionUsers);

  CollectionReference<Map<String, dynamic>> get _praxenRef =>
      _firestore.collection(AppConstants.collectionPraxen);

  CollectionReference<Map<String, dynamic>> _patientenRef(String praxisId) =>
      _praxenRef
          .doc(praxisId)
          .collection(AppConstants.collectionPatienten);

  CollectionReference<Map<String, dynamic>> _therapeutenRef(String praxisId) =>
      _praxenRef
          .doc(praxisId)
          .collection(AppConstants.collectionTherapeuten);

  CollectionReference<Map<String, dynamic>> _termineRef(String praxisId) =>
      _praxenRef
          .doc(praxisId)
          .collection(AppConstants.collectionTermine);

  CollectionReference<Map<String, dynamic>> _notizenRef(
    String praxisId,
    String patientId,
  ) =>
      _patientenRef(praxisId)
          .doc(patientId)
          .collection(AppConstants.collectionNotes);

  // ============================================================
  // Auth
  // ============================================================

  /// Der aktuell eingeloggte Firebase-User oder null.
  User? get currentUser => _auth.currentUser;

  /// Stream fuer Auth-Status-Aenderungen.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Gibt die Praxis-ID des eingeloggten Nutzers zurueck.
  ///
  /// Liest aus dem /users/{uid} Dokument, das bei der Registrierung
  /// angelegt wird. Das Ergebnis wird gecacht.
  ///
  /// Falls das User-Dokument nicht existiert (z.B. weil die Firestore-
  /// Regeln bei der Registrierung die Schreiboperation blockiert haben),
  /// wird automatisch eine neue Praxis und ein User-Dokument erstellt.
  Future<String?> get currentPraxisId async {
    if (_cachedPraxisId != null) return _cachedPraxisId;

    final user = currentUser;
    if (user == null) return null;

    final doc = await _usersRef.doc(user.uid).get();
    if (doc.exists) {
      _cachedPraxisId = doc.data()?['praxisId'] as String?;
      return _cachedPraxisId;
    }

    // Self-healing Schritt 1: Bereits existierende Praxis per Email suchen.
    // Verhindert, dass Geister-Praxen mit schlechten Namen entstehen,
    // wenn signUp die Praxis erstellt, aber das User-Mapping verloren ging.
    final email = user.email ?? '';
    if (email.isNotEmpty) {
      final existing = await _praxenRef
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        final praxisId = existing.docs.first.id;
        await _usersRef.doc(user.uid).set({
          'email': email,
          'praxisId': praxisId,
          'praxisIds': [praxisId],
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _cachedPraxisId = praxisId;
        return _cachedPraxisId;
      }
    }

    // Schritt 2: Wirklich keine Praxis vorhanden -> neue anlegen.
    // Verwendet einen neutralen Default-Namen, den der Nutzer
    // in den Einstellungen aendern kann.
    final praxisDoc = _praxenRef.doc();
    final praxis = Praxis(
      id: praxisDoc.id,
      name: 'Meine Praxis',
      email: email,
      createdAt: DateTime.now(),
    );
    await praxisDoc.set(praxis.toFirestore());

    await _usersRef.doc(user.uid).set({
      'email': email,
      'praxisId': praxisDoc.id,
      'praxisIds': [praxisDoc.id],
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    _cachedPraxisId = praxisDoc.id;
    return _cachedPraxisId;
  }

  /// Setzt den gecachten Praxis-ID-Wert manuell (z.B. nach Login).
  void setCachedPraxisId(String? praxisId) {
    _cachedPraxisId = praxisId;
  }

  /// Meldet einen bestehenden Nutzer an.
  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Cache leeren, damit er bei Bedarf neu geladen wird.
    _cachedPraxisId = null;
    return credential;
  }

  /// Registriert einen neuen Nutzer und erstellt die zugehoerige Praxis.
  ///
  /// 1. Firebase-Auth-Account anlegen
  /// 2. Praxis-Dokument erstellen
  /// 3. User-Dokument mit praxisId-Mapping erstellen
  Future<UserCredential> signUp(
    String email,
    String password,
    String praxisName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    // Praxis erstellen
    final praxisDoc = _praxenRef.doc();
    final praxis = Praxis(
      id: praxisDoc.id,
      name: praxisName.trim(),
      email: email.trim(),
      createdAt: DateTime.now(),
    );
    await praxisDoc.set(praxis.toFirestore());

    // User-Dokument mit Praxis-Mapping (Ersteller = Admin)
    await _usersRef.doc(uid).set({
      'email': email.trim(),
      'praxisId': praxisDoc.id,
      'praxisIds': [praxisDoc.id],
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    _cachedPraxisId = praxisDoc.id;
    return credential;
  }

  /// Meldet den aktuellen Nutzer ab.
  Future<void> signOut() async {
    _cachedPraxisId = null;
    await _auth.signOut();
  }

  // ============================================================
  // Praxis
  // ============================================================

  /// Erstellt eine neue Praxis und gibt die ID zurueck.
  Future<String> createPraxis(Praxis praxis) async {
    final doc = _praxenRef.doc(praxis.id.isNotEmpty ? praxis.id : null);
    await doc.set(praxis.toFirestore());
    return doc.id;
  }

  /// Laedt eine einzelne Praxis anhand ihrer ID.
  Future<Praxis?> getPraxis(String id) async {
    final doc = await _praxenRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Praxis.fromFirestore(doc);
  }

  /// Aktualisiert eine bestehende Praxis.
  Future<void> updatePraxis(Praxis praxis) async {
    await _praxenRef.doc(praxis.id).update(praxis.toFirestore());
  }

  // ============================================================
  // Multi-Standort
  // ============================================================

  /// Gibt alle Praxis-IDs des aktuellen Nutzers zurueck.
  Future<List<String>> get currentPraxisIds async {
    final user = currentUser;
    if (user == null) return [];

    final doc = await _usersRef.doc(user.uid).get();
    if (!doc.exists) return [];

    final data = doc.data();
    if (data == null) return [];

    // Abwaertskompatibel: wenn praxisIds nicht existiert, nur praxisId verwenden
    final praxisIds = data['praxisIds'] as List<dynamic>?;
    if (praxisIds != null && praxisIds.isNotEmpty) {
      return praxisIds.cast<String>();
    }

    final singleId = data['praxisId'] as String?;
    if (singleId != null && singleId.isNotEmpty) {
      // Migration: praxisIds Array aus dem einzelnen Wert erstellen
      await _usersRef.doc(user.uid).update({
        'praxisIds': [singleId],
      });
      return [singleId];
    }

    return [];
  }

  /// Laedt alle Praxen des aktuellen Nutzers.
  ///
  /// Faengt Fehler bei einzelnen Standorten ab (z.B. Permission-Denied
  /// bei veralteten Firestore-Regeln) und gibt nur die lesbaren zurueck.
  Future<List<Praxis>> getStandorte() async {
    final ids = await currentPraxisIds;
    if (ids.isEmpty) return [];

    final results = <Praxis>[];
    for (final id in ids) {
      try {
        final praxis = await getPraxis(id);
        if (praxis != null) results.add(praxis);
      } catch (e) {
        // Permission denied oder Netzwerkfehler — Standort ueberspringen
        // ignore: avoid_print
        print('Standort $id nicht ladbar: $e');
      }
    }
    return results;
  }

  /// Erstellt einen neuen Standort und fuegt ihn zum User hinzu.
  Future<Praxis> addStandort(String name) async {
    final user = currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');

    final praxisDoc = _praxenRef.doc();
    final praxis = Praxis(
      id: praxisDoc.id,
      name: name.trim(),
      email: user.email ?? '',
      createdAt: DateTime.now(),
    );
    await praxisDoc.set(praxis.toFirestore());

    // Zum User-Dokument hinzufuegen
    await _usersRef.doc(user.uid).update({
      'praxisIds': FieldValue.arrayUnion([praxisDoc.id]),
    });

    return praxis;
  }

  /// Entfernt einen Standort vom User (loescht die Praxis-Daten NICHT).
  Future<void> removeStandort(String praxisId) async {
    final user = currentUser;
    if (user == null) return;

    await _usersRef.doc(user.uid).update({
      'praxisIds': FieldValue.arrayRemove([praxisId]),
    });

    // Falls der entfernte Standort der aktive war, zum ersten wechseln
    if (_cachedPraxisId == praxisId) {
      final remaining = await currentPraxisIds;
      if (remaining.isNotEmpty) {
        await switchStandort(remaining.first);
      } else {
        _cachedPraxisId = null;
      }
    }
  }

  /// Wechselt den aktiven Standort.
  Future<void> switchStandort(String praxisId) async {
    final user = currentUser;
    if (user == null) return;

    _cachedPraxisId = praxisId;
    await _usersRef.doc(user.uid).update({
      'praxisId': praxisId,
    });
  }

  /// Laedt Patienten aus mehreren Standorten zusammen.
  Future<List<Patient>> getPatientenMultiStandort(
    List<String> praxisIds,
  ) async {
    final allPatienten = <Patient>[];
    for (final id in praxisIds) {
      final snapshot = await _patientenRef(id).get();
      allPatienten.addAll(
        snapshot.docs.map((doc) => Patient.fromFirestore(doc)),
      );
    }
    allPatienten.sort((a, b) => b.anmeldung.compareTo(a.anmeldung));
    return allPatienten;
  }

  // ============================================================
  // Patienten
  // ============================================================

  /// Echtzeit-Stream aller Patienten einer Praxis, sortiert nach Anmeldung.
  Stream<List<Patient>> getPatienten(String praxisId) {
    return _patientenRef(praxisId)
        .orderBy('anmeldung', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Patient.fromFirestore(doc))
            .toList());
  }

  /// Echtzeit-Stream der Patienten nach Status gefiltert.
  Stream<List<Patient>> getPatientenByStatus(
    String praxisId,
    PatientStatus status,
  ) {
    return _patientenRef(praxisId)
        .where('status', isEqualTo: status.name)
        .orderBy('anmeldung', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Patient.fromFirestore(doc))
            .toList());
  }

  /// Fuegt einen neuen Patienten hinzu und gibt die generierte ID zurueck.
  Future<String> addPatient(Patient patient) async {
    final doc = await _patientenRef(patient.praxisId).add(
      patient.toFirestore(),
    );
    return doc.id;
  }

  /// Aktualisiert einen bestehenden Patienten.
  Future<void> updatePatient(Patient patient) async {
    await _patientenRef(patient.praxisId)
        .doc(patient.id)
        .update(patient.toFirestore());
  }

  /// Loescht einen Patienten.
  Future<void> deletePatient(String praxisId, String patientId) async {
    await _patientenRef(praxisId).doc(patientId).delete();
  }

  /// Aendert nur den Status eines Patienten.
  ///
  /// Bei Wechsel zu [PatientStatus.platzGefunden] wird automatisch
  /// das Datum [platzGefundenAm] gesetzt.
  Future<void> updatePatientStatus(
    String praxisId,
    String patientId,
    PatientStatus status,
  ) async {
    final Map<String, dynamic> data = {'status': status.name};

    if (status == PatientStatus.platzGefunden) {
      data['platzGefundenAm'] = Timestamp.fromDate(DateTime.now());
    }

    await _patientenRef(praxisId).doc(patientId).update(data);
  }

  /// Sucht Patienten nach Name, Vorname oder Stoerungsbild (client-seitig).
  ///
  /// Firestore unterstuetzt keine native Volltextsuche, daher laden wir
  /// alle Patienten und filtern lokal. Fuer grosse Datensaetze sollte
  /// Algolia oder eine Cloud-Function-basierte Loesung verwendet werden.
  Future<List<Patient>> searchPatienten(
    String praxisId,
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    final snapshot = await _patientenRef(praxisId).get();
    final normalizedQuery = query.trim().toLowerCase();

    return snapshot.docs
        .map((doc) => Patient.fromFirestore(doc))
        .where((patient) {
      final fullName = patient.vollstaendigerName.toLowerCase();
      final stoerung = patient.stoerungsbild.toLowerCase();
      final telefon = patient.telefon.toLowerCase();
      return fullName.contains(normalizedQuery) ||
          stoerung.contains(normalizedQuery) ||
          telefon.contains(normalizedQuery);
    }).toList();
  }

  // ============================================================
  // Therapeuten
  // ============================================================

  /// Echtzeit-Stream aller Therapeuten einer Praxis.
  Stream<List<Therapeut>> getTherapeuten(String praxisId) {
    return _therapeutenRef(praxisId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Therapeut.fromFirestore(doc))
            .toList());
  }

  /// Fuegt einen neuen Therapeuten hinzu.
  Future<String> addTherapeut(Therapeut therapeut) async {
    final doc = await _therapeutenRef(therapeut.praxisId).add(
      therapeut.toFirestore(),
    );
    return doc.id;
  }

  /// Aktualisiert einen bestehenden Therapeuten.
  Future<void> updateTherapeut(Therapeut therapeut) async {
    await _therapeutenRef(therapeut.praxisId)
        .doc(therapeut.id)
        .update(therapeut.toFirestore());
  }

  /// Loescht einen Therapeuten.
  Future<void> deleteTherapeut(String praxisId, String therapeutId) async {
    await _therapeutenRef(praxisId).doc(therapeutId).delete();
  }

  /// Zaehlt die aktiven Patienten pro Therapeut (status: wartend, platzGefunden, inBehandlung).
  Future<Map<String, int>> getTherapeutAuslastung(String praxisId) async {
    final snapshot = await _patientenRef(praxisId).get();
    final counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final therapeutId = data['therapeutId'] as String?;
      final status = data['status'] as String? ?? 'wartend';
      if (therapeutId != null &&
          therapeutId.isNotEmpty &&
          status != 'abgeschlossen') {
        counts[therapeutId] = (counts[therapeutId] ?? 0) + 1;
      }
    }
    return counts;
  }

  // ============================================================
  // Termine
  // ============================================================

  /// Echtzeit-Stream aller Termine einer Praxis, sortiert nach Datum.
  Stream<List<Termin>> getTermine(String praxisId) {
    return _termineRef(praxisId)
        .orderBy('datum', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Termin.fromFirestore(doc))
            .toList());
  }

  /// Fuegt einen neuen Termin hinzu.
  Future<String> addTermin(Termin termin) async {
    final doc = await _termineRef(termin.praxisId).add(
      termin.toFirestore(),
    );
    return doc.id;
  }

  /// Loescht einen Termin.
  Future<void> deleteTermin(String praxisId, String terminId) async {
    await _termineRef(praxisId).doc(terminId).delete();
  }

  // ============================================================
  // Notizen / Anruf-Protokoll
  // ============================================================

  /// Echtzeit-Stream aller Notizen eines Patienten, neueste zuerst.
  Stream<List<PatientNote>> getNotizen(String praxisId, String patientId) {
    return _notizenRef(praxisId, patientId)
        .orderBy('erstelltAm', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PatientNote.fromFirestore(doc))
            .toList());
  }

  /// Fuegt eine neue Notiz hinzu und gibt die generierte ID zurueck.
  ///
  /// Bei Anruf- oder E-Mail-Notizen wird automatisch das Feld
  /// [letzterKontakt] des Patienten aktualisiert.
  Future<String> addNotiz(PatientNote note) async {
    final doc = await _notizenRef(note.praxisId, note.patientId).add(
      note.toFirestore(),
    );

    // Letzter Kontakt automatisch aktualisieren
    if (note.typ == NoteType.anruf || note.typ == NoteType.email) {
      await _patientenRef(note.praxisId)
          .doc(note.patientId)
          .update({'letzterKontakt': Timestamp.fromDate(note.erstelltAm)});
    }

    return doc.id;
  }

  /// Loescht eine Notiz.
  Future<void> deleteNotiz(
    String praxisId,
    String patientId,
    String noteId,
  ) async {
    await _notizenRef(praxisId, patientId).doc(noteId).delete();
  }

  // ============================================================
  // Benutzer & Rollen
  // ============================================================

  /// Laedt das AppUser-Objekt des aktuell eingeloggten Nutzers.
  Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await _usersRef.doc(user.uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromFirestore(doc);
  }

  /// Gibt die Rolle des aktuellen Nutzers zurueck.
  Future<UserRole> getCurrentUserRole() async {
    final appUser = await getCurrentAppUser();
    return appUser?.role ?? UserRole.admin;
  }

  /// Laedt alle Mitarbeiter (User-Dokumente), die Zugriff auf eine
  /// bestimmte Praxis haben.
  Future<List<AppUser>> getMitarbeiter(String praxisId) async {
    final snapshot = await _usersRef
        .where('praxisIds', arrayContains: praxisId)
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .toList()
      ..sort((a, b) => a.email.compareTo(b.email));
  }

  /// Fuegt einen neuen Mitarbeiter per E-Mail zu einem Standort hinzu.
  ///
  /// Sucht zuerst, ob ein User mit dieser E-Mail existiert.
  /// Falls ja: fuegt die praxisId zum praxisIds Array hinzu.
  /// Falls nein: erstellt ein Einladungs-Dokument in /invites.
  Future<bool> inviteMitarbeiter(String email, String praxisId) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Existierenden User suchen
    final existing = await _usersRef
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // User existiert bereits → Standort hinzufuegen + Rolle auf 'user' setzen
      final userDoc = existing.docs.first;
      final currentRole = userDoc.data()['role'] as String? ?? 'admin';

      final updates = <String, dynamic>{
        'praxisIds': FieldValue.arrayUnion([praxisId]),
      };

      // Nur Rolle setzen, wenn noch keine gesetzt ist
      if (currentRole != 'admin') {
        updates['role'] = 'user';
      }

      await _usersRef.doc(userDoc.id).update(updates);
      return true;
    }

    // User existiert noch nicht → Einladung speichern
    // Wenn der User sich registriert, wird die Einladung eingeloest
    await _firestore.collection('invites').add({
      'email': normalizedEmail,
      'praxisId': praxisId,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUser?.uid,
    });

    return false;
  }

  /// Prueft ob offene Einladungen fuer den aktuellen User vorliegen
  /// und loest sie ein (fuegt praxisIds hinzu).
  Future<void> redeemInvites() async {
    final user = currentUser;
    if (user == null || user.email == null) return;

    final invites = await _firestore
        .collection('invites')
        .where('email', isEqualTo: user.email!.toLowerCase())
        .get();

    if (invites.docs.isEmpty) return;

    for (final invite in invites.docs) {
      final praxisId = invite.data()['praxisId'] as String?;
      if (praxisId != null) {
        await _usersRef.doc(user.uid).update({
          'praxisIds': FieldValue.arrayUnion([praxisId]),
        });
      }
      // Einladung loeschen
      await invite.reference.delete();
    }
  }

  /// Entfernt einen Mitarbeiter aus einem Standort.
  Future<void> removeMitarbeiter(String userUid, String praxisId) async {
    await _usersRef.doc(userUid).update({
      'praxisIds': FieldValue.arrayRemove([praxisId]),
    });

    // Falls der entfernte Standort der aktive war, zum ersten verbleibenden wechseln
    final userDoc = await _usersRef.doc(userUid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      final currentPraxis = data?['praxisId'] as String?;
      if (currentPraxis == praxisId) {
        final remaining =
            (data?['praxisIds'] as List<dynamic>?)?.cast<String>() ?? [];
        if (remaining.isNotEmpty) {
          await _usersRef.doc(userUid).update({'praxisId': remaining.first});
        }
      }
    }
  }

  /// Aendert die Rolle eines Nutzers.
  Future<void> updateUserRole(String userUid, UserRole role) async {
    await _usersRef.doc(userUid).update({'role': role.name});
  }

  // ============================================================
  // Statistiken
  // ============================================================

  /// Berechnet monatliche Statistiken fuer ein ganzes Jahr.
  ///
  /// Gibt eine Map zurueck mit:
  /// - 'monthly': Liste mit 12 Eintraegen (Jan-Dez), je Map mit
  ///   'total', 'wartend', 'platzGefunden', 'inBehandlung', 'abgeschlossen'
  /// - 'yearTotal': Gesamtanzahl im Jahr
  /// - 'yearWartend': Gesamt wartend
  /// - 'yearPlatzGefunden': Gesamt Platz gefunden
  Future<Map<String, dynamic>> getMonthlyStats(
    String praxisId,
    int year,
  ) async {
    final snapshot = await _patientenRef(praxisId).get();
    final allPatienten = snapshot.docs
        .map((doc) => Patient.fromFirestore(doc))
        .toList();

    final List<Map<String, int>> monthly = List.generate(12, (index) {
      final monatStr =
          '$year-${(index + 1).toString().padLeft(2, '0')}';

      final monatPatienten =
          allPatienten.where((p) => p.monat == monatStr).toList();

      return {
        'total': monatPatienten.length,
        'wartend': monatPatienten
            .where((p) => p.status == PatientStatus.wartend)
            .length,
        'platzGefunden': monatPatienten
            .where((p) => p.status == PatientStatus.platzGefunden)
            .length,
        'inBehandlung': monatPatienten
            .where((p) => p.status == PatientStatus.inBehandlung)
            .length,
        'abgeschlossen': monatPatienten
            .where((p) => p.status == PatientStatus.abgeschlossen)
            .length,
      };
    });

    // Jahrestotale
    final yearPatienten = allPatienten
        .where((p) => p.monat.startsWith('$year'))
        .toList();

    return {
      'monthly': monthly,
      'yearTotal': yearPatienten.length,
      'yearWartend': yearPatienten
          .where((p) => p.status == PatientStatus.wartend)
          .length,
      'yearPlatzGefunden': yearPatienten
          .where((p) => p.status == PatientStatus.platzGefunden)
          .length,
      'yearInBehandlung': yearPatienten
          .where((p) => p.status == PatientStatus.inBehandlung)
          .length,
      'yearAbgeschlossen': yearPatienten
          .where((p) => p.status == PatientStatus.abgeschlossen)
          .length,
    };
  }
}
