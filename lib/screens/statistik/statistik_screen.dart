import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/patient.dart';
import '../../providers/patienten_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/chart_widgets.dart';

/// Navigiert zur Warteliste mit optionalem Filter.
///
/// Setzt zuerst alle Filter zurueck, dann nur den gewuenschten.
void _navigateToWarteliste(
  WidgetRef ref, {
  String? monatFilter,
  String? stoerungsbildFilter,
  String? versicherungFilter,
  SortOption? sortOption,
}) {
  // Alle Filter zuruecksetzen
  ref.read(monatFilterProvider.notifier).state = null;
  ref.read(stoerungsbildFilterProvider.notifier).state = null;
  ref.read(versicherungFilterProvider.notifier).state = null;
  ref.read(searchQueryProvider.notifier).state = '';

  // Nur den gewuenschten Filter setzen
  if (monatFilter != null) {
    ref.read(monatFilterProvider.notifier).state = monatFilter;
  }
  if (stoerungsbildFilter != null) {
    ref.read(stoerungsbildFilterProvider.notifier).state = stoerungsbildFilter;
  }
  if (versicherungFilter != null) {
    ref.read(versicherungFilterProvider.notifier).state = versicherungFilter;
  }
  if (sortOption != null) {
    ref.read(sortOptionProvider.notifier).state = sortOption;
  }

  // Warteliste Tab 0 (Alle) und dann Bottom Nav auf Warteliste (1)
  ref.read(wartelisteTabIndexProvider.notifier).state = 0;
  ref.read(dashboardNavIndexProvider.notifier).state = 1;
}

/// Statistik-Screen mit Diagrammen zur Wartelisten-Analyse.
///
/// Zeigt Jahresauswahl und fuenf Statistik-Karten:
/// 1. Monatliche Anmeldungen (Balkendiagramm)
/// 2. Stoerungsbild-Verteilung (Kreisdiagramm)
/// 3. Versicherung KK/Privat (Kreisdiagramm)
/// 4. Auslastung pro Monat (Liniendiagramm)
/// 5. Durchschnittliche Wartezeit (Zahl)
class StatistikScreen extends ConsumerStatefulWidget {
  const StatistikScreen({super.key});

  @override
  ConsumerState<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends ConsumerState<StatistikScreen> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  /// Filtert Patienten nach dem gewaehlten Jahr.
  List<Patient> _filterByYear(List<Patient> patienten) {
    final yearPrefix = '$_selectedYear';
    return patienten
        .where((p) => p.monat.startsWith(yearPrefix))
        .toList();
  }

  /// Berechnet die monatlichen Anmeldungen (Map: Monat 1-12 -> Anzahl).
  Map<int, int> _monthlyRegistrations(List<Patient> patienten) {
    final result = <int, int>{};
    for (int m = 1; m <= 12; m++) {
      final monatStr =
          '$_selectedYear-${m.toString().padLeft(2, '0')}';
      result[m] = patienten.where((p) => p.monat == monatStr).length;
    }
    return result;
  }

  /// Berechnet die Stoerungsbild-Verteilung.
  Map<String, int> _disorderDistribution(List<Patient> patienten) {
    final result = <String, int>{};
    for (final p in patienten) {
      final key = p.stoerungsbild.isEmpty ? 'Unbekannt' : p.stoerungsbild;
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  /// Zaehlt KK vs Privat.
  ({int kk, int privat}) _insuranceCounts(List<Patient> patienten) {
    int kk = 0;
    int privat = 0;
    for (final p in patienten) {
      if (p.versicherung.toLowerCase() == 'privat') {
        privat++;
      } else {
        kk++;
      }
    }
    return (kk: kk, privat: privat);
  }

  /// Berechnet die monatliche Auslastung (% platzGefunden pro Monat).
  Map<int, double> _monthlyUtilization(List<Patient> patienten) {
    final result = <int, double>{};
    for (int m = 1; m <= 12; m++) {
      final monatStr =
          '$_selectedYear-${m.toString().padLeft(2, '0')}';
      final monatPatienten =
          patienten.where((p) => p.monat == monatStr).toList();
      if (monatPatienten.isEmpty) {
        result[m] = 0;
      } else {
        final platzGefunden = monatPatienten
            .where((p) =>
                p.status == PatientStatus.platzGefunden ||
                p.status == PatientStatus.inBehandlung ||
                p.status == PatientStatus.abgeschlossen)
            .length;
        result[m] = (platzGefunden / monatPatienten.length) * 100;
      }
    }
    return result;
  }

  /// Berechnet die durchschnittliche Wartezeit in Tagen.
  int _averageWaitDays(List<Patient> patienten) {
    final wartende =
        patienten.where((p) => p.status == PatientStatus.wartend).toList();
    if (wartende.isEmpty) return 0;
    final totalDays =
        wartende.fold<int>(0, (sum, p) => sum + p.wartezeitInTagen);
    return (totalDays / wartende.length).round();
  }

  /// Erzeugt die Liste der verfuegbaren Jahre.
  List<int> _availableYears(List<Patient> patienten) {
    final years = <int>{};
    for (final p in patienten) {
      final parts = p.monat.split('-');
      if (parts.isNotEmpty) {
        final year = int.tryParse(parts[0]);
        if (year != null) years.add(year);
      }
    }
    // Aktuelles Jahr immer anzeigen
    years.add(DateTime.now().year);
    final sorted = years.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final asyncPatienten = ref.watch(patientenProvider);

    return asyncPatienten.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(
                'Fehler beim Laden der Daten',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                error.toString(),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (allPatienten) {
          final years = _availableYears(allPatienten);
          final patienten = _filterByYear(allPatienten);
          final monthlyData = _monthlyRegistrations(patienten);
          final disorderData = _disorderDistribution(patienten);
          final insurance = _insuranceCounts(patienten);
          final utilization = _monthlyUtilization(patienten);
          final avgWait = _averageWaitDays(patienten);

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // ── Jahresauswahl ──
              _YearSelector(
                years: years,
                selectedYear: _selectedYear,
                onYearChanged: (year) => setState(() => _selectedYear = year),
              ),
              const SizedBox(height: 8),

              // ── Zusammenfassung ──
              _SummaryRow(
                total: patienten.length,
                wartend: patienten
                    .where((p) => p.status == PatientStatus.wartend)
                    .length,
                platzGefunden: patienten
                    .where((p) =>
                        p.status == PatientStatus.platzGefunden ||
                        p.status == PatientStatus.inBehandlung ||
                        p.status == PatientStatus.abgeschlossen)
                    .length,
                onTotalTap: () {
                  ref.read(wartelisteTabIndexProvider.notifier).state = 0;
                  ref.read(dashboardNavIndexProvider.notifier).state = 1;
                },
                onWartendTap: () {
                  ref.read(wartelisteTabIndexProvider.notifier).state = 1;
                  ref.read(dashboardNavIndexProvider.notifier).state = 1;
                },
                onPlatzGefundenTap: () {
                  ref.read(wartelisteTabIndexProvider.notifier).state = 2;
                  ref.read(dashboardNavIndexProvider.notifier).state = 1;
                },
              ),
              const SizedBox(height: 4),

              // ── 1. Monatliche Anmeldungen ──
              _ChartCard(
                title: 'Monatliche Anmeldungen',
                icon: Icons.bar_chart_rounded,
                hint: 'Tippen zum Filtern',
                child: MonthlyBarChart(
                  data: monthlyData,
                  onBarTap: (month) {
                    final monatStr =
                        '$_selectedYear-${month.toString().padLeft(2, '0')}';
                    _navigateToWarteliste(ref, monatFilter: monatStr);
                  },
                ),
              ),

              // ── 2. Stoerungsbild-Verteilung ──
              _ChartCard(
                title: 'Stoerungsbild-Verteilung',
                icon: Icons.pie_chart_rounded,
                hint: 'Tippen zum Filtern',
                child: DisorderPieChart(
                  data: disorderData,
                  onItemTap: (disorder) {
                    _navigateToWarteliste(ref,
                        stoerungsbildFilter: disorder);
                  },
                ),
              ),

              // ── 3. Versicherung ──
              _ChartCard(
                title: 'Versicherung',
                icon: Icons.health_and_safety_rounded,
                hint: 'Tippen zum Filtern',
                child: InsurancePieChart(
                  kk: insurance.kk,
                  privat: insurance.privat,
                  onItemTap: (versicherung) {
                    _navigateToWarteliste(ref,
                        versicherungFilter: versicherung);
                  },
                ),
              ),

              // ── 4. Auslastung pro Monat ──
              _ChartCard(
                title: 'Auslastung pro Monat',
                icon: Icons.show_chart_rounded,
                child: AuslastungLineChart(percentages: utilization),
              ),

              // ── 5. Durchschnittliche Wartezeit ──
              _WaitTimeCard(
                avgDays: avgWait,
                onTap: () {
                  _navigateToWarteliste(ref,
                      sortOption: SortOption.wartezeit);
                },
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      );
  }
}

// ──────────────────────────────────────────────
// Jahresauswahl
// ──────────────────────────────────────────────

class _YearSelector extends StatelessWidget {
  final List<int> years;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  const _YearSelector({
    required this.years,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: years.map((year) {
            final isSelected = year == selectedYear;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$year'),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                onSelected: (_) => onYearChanged(year),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Zusammenfassungszeile
// ──────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int total;
  final int wartend;
  final int platzGefunden;
  final VoidCallback? onTotalTap;
  final VoidCallback? onWartendTap;
  final VoidCallback? onPlatzGefundenTap;

  const _SummaryRow({
    required this.total,
    required this.wartend,
    required this.platzGefunden,
    this.onTotalTap,
    this.onWartendTap,
    this.onPlatzGefundenTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              label: 'Gesamt',
              value: '$total',
              color: AppTheme.primaryColor,
              onTap: onTotalTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MiniStat(
              label: 'Wartend',
              value: '$wartend',
              color: AppTheme.statusWartend,
              onTap: onWartendTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MiniStat(
              label: 'Vermittelt',
              value: '$platzGefunden',
              color: AppTheme.successColor,
              onTap: onPlatzGefundenTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Chart-Card Wrapper
// ──────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final String? hint;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Wartezeit-Karte
// ──────────────────────────────────────────────

class _WaitTimeCard extends StatelessWidget {
  final int avgDays;
  final VoidCallback? onTap;

  const _WaitTimeCard({required this.avgDays, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = avgDays > 90
        ? AppTheme.errorColor
        : avgDays > 45
            ? AppTheme.warningColor
            : AppTheme.primaryColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ø Wartezeit',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      avgDays == 0
                          ? 'Keine wartenden Patienten'
                          : avgDays > 90
                              ? 'Kritisch hoch'
                              : avgDays > 45
                                  ? 'Erhoeht'
                                  : 'Im Rahmen',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Text(
                '$avgDays',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Tage',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
