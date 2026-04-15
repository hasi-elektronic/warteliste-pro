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

  const AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    required this.role,
    required this.praxisId,
    required this.praxisIds,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;

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
