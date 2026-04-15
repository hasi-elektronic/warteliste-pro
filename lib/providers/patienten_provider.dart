import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/patient.dart';
import '../models/patient_note.dart';
import '../services/firebase_service.dart';

/// Provider fuer den FirebaseService (Singleton).
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

/// Provider fuer die aktuelle Praxis-ID.
///
/// Muss beim Login gesetzt werden via [praxisIdProvider.overrideWithValue]
/// oder durch einen FutureProvider der die ID laedt.
final praxisIdProvider = StateProvider<String?>((ref) => null);

/// Echtzeit-Stream aller Patienten der aktuellen Praxis.
final patientenProvider = StreamProvider<List<Patient>>((ref) {
  final praxisId = ref.watch(praxisIdProvider);
  if (praxisId == null || praxisId.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(firebaseServiceProvider);
  return service.getPatienten(praxisId);
});

/// Sortierung fuer die Warteliste.
enum SortOption { datum, name, wartezeit, prioritaet }

/// Aktuell gewaehlte Sortierung.
final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.datum);

/// Suchbegriff fuer die Warteliste.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Ausgewaehlter Stoerungsbild-Filter (null = alle).
final stoerungsbildFilterProvider = StateProvider<String?>((ref) => null);

/// Ausgewaehlter Versicherungs-Filter (null = alle).
final versicherungFilterProvider = StateProvider<String?>((ref) => null);

/// Ausgewaehlter Monats-Filter (null = alle).
final monatFilterProvider = StateProvider<String?>((ref) => null);

/// Ausgewaehlter Prioritaets-Filter (null = alle).
final prioritaetFilterProvider =
    StateProvider<PatientPrioritaet?>((ref) => null);

/// Nur Rezept-Warnungen anzeigen.
final nurRezeptWarnungProvider = StateProvider<bool>((ref) => false);

/// Aktiver Bottom-Navigation-Tab (0=Dashboard, 1=Warteliste, 2=Statistik, 3=Einstellungen).
final dashboardNavIndexProvider = StateProvider<int>((ref) => 0);

/// Initial-Tab fuer den Warteliste-Screen
/// (0=Alle, 1=Wartend, 2=Platz gefunden, 3=In Behandlung).
final wartelisteTabIndexProvider = StateProvider<int>((ref) => 0);

/// Echtzeit-Stream der Notizen eines Patienten.
///
/// Verwendet [StreamProvider.family] mit patientId als Parameter.
/// Die praxisId wird aus dem globalen [praxisIdProvider] gelesen.
final notizenProvider =
    StreamProvider.family<List<PatientNote>, String>((ref, patientId) {
  final praxisId = ref.watch(praxisIdProvider);
  if (praxisId == null || praxisId.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(firebaseServiceProvider);
  return service.getNotizen(praxisId, patientId);
});

/// Gefilterte und sortierte Patientenliste.
///
/// Kombiniert die Ergebnisse von [patientenProvider] mit Suche,
/// Filtern und Sortierung.
final gefiltertePatientenProvider = Provider<AsyncValue<List<Patient>>>((ref) {
  final asyncPatienten = ref.watch(patientenProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final stoerungsbildFilter = ref.watch(stoerungsbildFilterProvider);
  final versicherungFilter = ref.watch(versicherungFilterProvider);
  final monatFilter = ref.watch(monatFilterProvider);
  final prioritaetFilter = ref.watch(prioritaetFilterProvider);
  final nurRezeptWarnung = ref.watch(nurRezeptWarnungProvider);
  final sortOption = ref.watch(sortOptionProvider);

  return asyncPatienten.whenData((patienten) {
    var result = List<Patient>.from(patienten);

    // Suche
    if (query.isNotEmpty) {
      result = result.where((p) {
        final fullName = p.vollstaendigerName.toLowerCase();
        final stoerung = p.stoerungsbild.toLowerCase();
        return fullName.contains(query) || stoerung.contains(query);
      }).toList();
    }

    // Filter: Stoerungsbild
    if (stoerungsbildFilter != null) {
      result = result
          .where((p) => p.stoerungsbild == stoerungsbildFilter)
          .toList();
    }

    // Filter: Versicherung
    if (versicherungFilter != null) {
      result = result
          .where((p) => p.versicherung == versicherungFilter)
          .toList();
    }

    // Filter: Monat
    if (monatFilter != null) {
      result = result.where((p) => p.monat == monatFilter).toList();
    }

    // Filter: Prioritaet
    if (prioritaetFilter != null) {
      result = result
          .where((p) => p.prioritaet == prioritaetFilter)
          .toList();
    }

    // Filter: Nur Rezept-Warnungen
    if (nurRezeptWarnung) {
      result = result.where((p) => p.rezeptLaeuftAb).toList();
    }

    // Sortierung
    switch (sortOption) {
      case SortOption.datum:
        result.sort((a, b) => b.anmeldung.compareTo(a.anmeldung));
      case SortOption.name:
        result.sort((a, b) =>
            a.vollstaendigerName.compareTo(b.vollstaendigerName));
      case SortOption.wartezeit:
        result.sort((a, b) =>
            b.wartezeitInTagen.compareTo(a.wartezeitInTagen));
      case SortOption.prioritaet:
        result.sort((a, b) =>
            b.prioritaet.index.compareTo(a.prioritaet.index));
    }

    return result;
  });
});
