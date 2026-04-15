import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/firebase_service.dart';
import 'patienten_provider.dart';

/// Provider fuer den aktuell eingeloggten AppUser mit Rolle.
final appUserProvider =
    StateNotifierProvider<AppUserNotifier, AsyncValue<AppUser?>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  return AppUserNotifier(service);
});

class AppUserNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final FirebaseService _service;

  AppUserNotifier(this._service) : super(const AsyncValue.data(null));

  /// Laedt den aktuellen User aus Firestore.
  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final user = await _service.getCurrentAppUser();
      if (mounted) {
        state = AsyncValue.data(user);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Setzt den User direkt (z.B. nach Rollenaenderung).
  void setUser(AppUser? user) {
    state = AsyncValue.data(user);
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

/// Ob der aktuelle Nutzer Admin ist.
final isAdminProvider = Provider<bool>((ref) {
  final appUser = ref.watch(appUserProvider);
  return appUser.whenOrNull(
        data: (user) => user?.isAdmin ?? true,
      ) ??
      true; // Default: admin (Abwaertskompatibilitaet)
});

/// Die Rolle des aktuellen Nutzers.
final userRoleProvider = Provider<UserRole>((ref) {
  final appUser = ref.watch(appUserProvider);
  return appUser.whenOrNull(
        data: (user) => user?.role ?? UserRole.admin,
      ) ??
      UserRole.admin;
});
