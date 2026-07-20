import 'package:cloud_firestore/cloud_firestore.dart';

/// Benutzerrollen in der App.
enum UserRole {
  /// Admin: Kann alle Standorte sehen/verwalten, Mitarbeiter einladen,
  /// Standorte hinzufuegen/entfernen.
  admin,

  /// Mitarbeiter: Sieht nur den zugewiesenen Standort,
  /// kann Patienten verwalten aber keine Standorte aendern.
  user,
}

/// Repraesentation eines App-Benutzers aus der /users/{uid} Collection.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String praxisId;
  final List<String> praxisIds;
  final DateTime createdAt;

  /// Wenn true: dem Nutzer wurde ein Passwort von uns voreingestellt.
  /// Die App zeigt eine Sicherheits-Warnung und bittet, es selbst zu ändern.
  final bool passwortAenderungEmpfohlen;

  const AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    required this.role,
    required this.praxisId,
    required this.praxisIds,
    required this.createdAt,
    this.passwortAenderungEmpfohlen = false,
  });

  bool get isAdmin => role == UserRole.admin;

  /// Baut einen AppUser aus dem Mitarbeiter-Index eines Standorts
  /// (`/praxen/{praxisId}/mitarbeiter/{uid}` mit { email, role }).
  ///
  /// Noetig, weil `users` client-seitig NICHT per Query gelesen werden kann:
  /// bei `list` ist `resource` in den Firestore-Rules null, eine
  /// datenabhaengige Regel ist dort nicht auswertbar.
  factory AppUser.fromMitarbeiterIndex(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String praxisId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final roleStr = data['role'] as String? ?? 'user';
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
      praxisId: praxisId,
      praxisIds: [praxisId],
      createdAt: data['joinedAt'] != null
          ? (data['joinedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final roleStr = data['role'] as String? ?? 'admin';
    final praxisIds = data['praxisIds'] as List<dynamic>?;
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: roleStr == 'user' ? UserRole.user : UserRole.admin,
      praxisId: data['praxisId'] as String? ?? '',
      praxisIds: praxisIds?.cast<String>() ?? [],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      passwortAenderungEmpfohlen:
          data['passwortAenderungEmpfohlen'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'praxisId': praxisId,
      'praxisIds': praxisIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? praxisId,
    List<String>? praxisIds,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      praxisId: praxisId ?? this.praxisId,
      praxisIds: praxisIds ?? this.praxisIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, role: ${role.name})';
}
