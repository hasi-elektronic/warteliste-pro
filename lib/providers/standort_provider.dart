import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/praxis.dart';
import '../services/firebase_service.dart';
import 'patienten_provider.dart';

/// Provider fuer die Liste aller Standorte des Nutzers.
///
/// Wird beim App-Start und bei Aenderungen aktualisiert.
final standorteProvider =
    StateNotifierProvider<StandorteNotifier, AsyncValue<List<Praxis>>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  return StandorteNotifier(service);
});

class StandorteNotifier extends StateNotifier<AsyncValue<List<Praxis>>> {
  final FirebaseService _service;

  StandorteNotifier(this._service) : super(const AsyncValue.data([])) {
    // Verzoegert laden, damit Firebase Auth bereit ist
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) load();
    });
  }

  /// Laedt alle Standorte des aktuellen Nutzers.
  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final standorte = await _service.getStandorte();
      if (mounted) {
        state = AsyncValue.data(standorte);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Fuegt einen neuen Standort hinzu.
  Future<Praxis> addStandort(String name) async {
    final praxis = await _service.addStandort(name);
    await load(); // Liste neu laden
    return praxis;
  }

  /// Entfernt einen Standort.
  Future<void> removeStandort(String praxisId) async {
    await _service.removeStandort(praxisId);
    await load();
  }
}

/// Provider fuer den aktuell aktiven Standort als Praxis-Objekt.
final aktivesPraxisProvider = Provider<Praxis?>((ref) {
  final praxisId = ref.watch(praxisIdProvider);
  final standorte = ref.watch(standorteProvider);

  return standorte.whenOrNull(
    data: (list) {
      if (praxisId == null || list.isEmpty) return null;
      try {
        return list.firstWhere((p) => p.id == praxisId);
      } catch (_) {
        return list.isNotEmpty ? list.first : null;
      }
    },
  );
});

/// Ob der Nutzer mehrere Standorte hat.
final hatMehrereStandorteProvider = Provider<bool>((ref) {
  final standorte = ref.watch(standorteProvider);
  return standorte.whenOrNull(
        data: (list) => list.length > 1,
      ) ??
      false;
});
