import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../models/patient.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patienten_provider.dart';
import '../../providers/standort_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/standort_switcher.dart';
import '../../widgets/web_layout.dart';
import '../warteliste/warteliste_screen.dart';
import '../statistik/statistik_screen.dart';
import '../einstellungen/einstellungen_screen.dart';

// ════════════════════════════════════════════════════════════════
// Dashboard-Screen (Shell mit BottomNavigationBar)
// ════════════════════════════════════════════════════════════════

/// Haupt-Screen der App mit Bottom-Navigation.
///
/// Tabs: Dashboard, Warteliste, Statistik, Einstellungen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const List<Widget> _tabs = [
    _DashboardContent(),
    WartelisteScreen(),
    StatistikScreen(),
    EinstellungenScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(dashboardNavIndexProvider);
    final hatMehrere = ref.watch(hatMehrereStandorteProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final aktivePraxis = ref.watch(aktivesPraxisProvider);
    final s = S.of(context);
    final titles = [s.appName, s.navWarteliste, s.navStatistik, s.navEinstellungen];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Text(
          titles[currentIndex],
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Nicht-Admin: Standort-Name
          if (!isAdmin && aktivePraxis != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                avatar: Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                label: Text(
                  aktivePraxis.name,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(s.dashboardKeineBenachrichtigungen),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              tooltip: s.dashboardBenachrichtigungen,
            ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: _tabs,
      ),
      floatingActionButton: currentIndex == 0 || currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).pushNamed('/patient/neu');
              },
              icon: const Icon(Icons.person_add_outlined),
              label: Text(s.dashboardNeuerPatient),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(dashboardNavIndexProvider.notifier).state = index;
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: s.navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_outlined),
            selectedIcon: const Icon(Icons.list),
            label: s.navWarteliste,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: s.navStatistik,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: s.navEinstellungen,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Dashboard-Inhalt (Tab 0)
// ════════════════════════════════════════════════════════════════

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Patienten-Daten aus Provider lesen.
    // Der Provider liefert AsyncValue<List<Patient>>.
    final patientenAsync = ref.watch(patientenProvider);

    return patientenAsync.when(
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
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      data: (patienten) => _DashboardBody(patienten: patienten),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final List<Patient> patienten;

  const _DashboardBody({required this.patienten});

  void _openWarteliste(WidgetRef ref, int tabIndex) {
    ref.read(wartelisteTabIndexProvider.notifier).state = tabIndex;
    ref.read(dashboardNavIndexProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wartend =
        patienten.where((p) => p.status == PatientStatus.wartend).length;
    final platzGefunden =
        patienten.where((p) => p.status == PatientStatus.platzGefunden).length;
    final gesamt = patienten.length;

    // Auslastung: Anteil der Patienten mit Platz oder in Behandlung.
    final versorgt = patienten
        .where((p) =>
            p.status == PatientStatus.platzGefunden ||
            p.status == PatientStatus.inBehandlung ||
            p.status == PatientStatus.abgeschlossen)
        .length;
    final auslastung = gesamt > 0 ? (versorgt / gesamt * 100).round() : 0;

    // Wartezeit-Warnungen
    final langeWartend = patienten
        .where((p) =>
            p.status == PatientStatus.wartend && p.wartezeitInTagen > 90)
        .toList()
      ..sort((a, b) => b.wartezeitInTagen.compareTo(a.wartezeitInTagen));
    final kritischWartend =
        langeWartend.where((p) => p.wartezeitInTagen > 180).length;

    // Rezept-Warnungen
    final rezeptWarnungen = patienten
        .where((p) =>
            p.status == PatientStatus.wartend && p.rezeptLaeuftAb)
        .toList();

    // Kontakt ueberfaellig
    final kontaktUeberfaellig = patienten
        .where((p) => p.kontaktUeberfaellig)
        .toList();

    // Durchschnittliche Wartezeit (nur wartende)
    final wartende = patienten
        .where((p) => p.status == PatientStatus.wartend)
        .toList();
    final durchschnittWartezeit = wartende.isNotEmpty
        ? (wartende.fold<int>(
                0, (sum, p) => sum + p.wartezeitInTagen) /
            wartende.length)
            .round()
        : 0;

    // Dringende Patienten
    final dringend = patienten
        .where((p) =>
            p.prioritaet == PatientPrioritaet.dringend &&
            p.status == PatientStatus.wartend)
        .length;

    // Monatliche Uebersicht: letzte 6 Monate.
    final now = DateTime.now();
    final monate = List.generate(6, (i) {
      final date = DateTime(now.year, now.month - (5 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final count = patienten.where((p) => p.monat == key).length;
      return _MonatDaten(
        label: _monatLabel(date.month),
        anzahl: count,
      );
    });

    final maxMonat =
        monate.fold<int>(1, (max, m) => m.anzahl > max ? m.anzahl : max);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Standort-Switcher (im Body, damit Riverpod rebuild funktioniert) ──
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: StandortSwitcher(),
          ),

          // ── KPI-Karten ──
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: KpiCard(
                    title: S.of(context).dashboardWartend,
                    value: '$wartend',
                    icon: Icons.hourglass_top,
                    color: AppTheme.statusWartend,
                    onTap: () => _openWarteliste(ref, 1),
                  ),
                ),
                Expanded(
                  child: KpiCard(
                    title: S.of(context).dashboardPlatzGefunden,
                    value: '$platzGefunden',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.successColor,
                    onTap: () => _openWarteliste(ref, 2),
                  ),
                ),
                Expanded(
                  child: KpiCard(
                    title: S.of(context).dashboardGesamt,
                    value: '$gesamt',
                    icon: Icons.people_outline,
                    color: AppTheme.primaryColor,
                    onTap: () => _openWarteliste(ref, 0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Zweite KPI-Zeile ──
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: KpiCard(
                    title: S.of(context).dashboardDurchschnittlicheWartezeit,
                    value: '$durchschnittWartezeit Tage',
                    icon: Icons.timer_outlined,
                    color: durchschnittWartezeit > 60
                        ? AppTheme.warningColor
                        : AppTheme.primaryColor,
                  ),
                ),
                if (dringend > 0)
                  Expanded(
                    child: KpiCard(
                      title: S.of(context).prioritaetDringend,
                      value: '$dringend',
                      icon: Icons.priority_high,
                      color: AppTheme.errorColor,
                      onTap: () => _openWarteliste(ref, 1),
                    ),
                  ),
                if (dringend == 0) const Expanded(child: SizedBox()),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Wartezeit-Warnung ──
          if (langeWartend.isNotEmpty)
            Card(
              color: kritischWartend > 0
                  ? AppTheme.errorColor.withValues(alpha: 0.08)
                  : AppTheme.warningColor.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: kritischWartend > 0
                      ? AppTheme.errorColor.withValues(alpha: 0.3)
                      : AppTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: InkWell(
                onTap: () => _openWarteliste(ref, 1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        kritischWartend > 0
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        color: kritischWartend > 0
                            ? AppTheme.errorColor
                            : AppTheme.warningColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${langeWartend.length} Patienten warten lange',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: kritischWartend > 0
                                        ? AppTheme.errorColor
                                        : AppTheme.warningColor,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              kritischWartend > 0
                                  ? '$kritischWartend kritisch (>180 Tage), ${langeWartend.length - kritischWartend} lang (>90 Tage)'
                                  : '${langeWartend.length} Patienten warten ueber 90 Tage',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (langeWartend.isNotEmpty) const SizedBox(height: 16),

          // ── Rezept-Warnung ──
          if (rezeptWarnungen.isNotEmpty)
            Card(
              color: AppTheme.warningColor.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: InkWell(
                onTap: () => _openWarteliste(ref, 1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long,
                          color: AppTheme.warningColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(context).dashboardRezeptWarnung(
                                  rezeptWarnungen.length),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.warningColor,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rezeptWarnungen
                                  .take(3)
                                  .map((p) => p.vollstaendigerName)
                                  .join(', '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          if (rezeptWarnungen.isNotEmpty) const SizedBox(height: 8),

          // ── Kontakt ueberfaellig ──
          if (kontaktUeberfaellig.isNotEmpty)
            Card(
              color: Colors.blue.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.blue.withValues(alpha: 0.25),
                ),
              ),
              child: InkWell(
                onTap: () => _openWarteliste(ref, 1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.contact_phone_outlined,
                          color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          S.of(context).dashboardKontaktWarnung(
                              kontaktUeberfaellig.length),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          if (kontaktUeberfaellig.isNotEmpty) const SizedBox(height: 16),

          // ── Auslastung ──
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: auslastung / 100,
                          strokeWidth: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            auslastung > 75
                                ? AppTheme.successColor
                                : auslastung > 40
                                    ? AppTheme.warningColor
                                    : AppTheme.errorColor,
                          ),
                        ),
                        Text(
                          '$auslastung%',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).dashboardAuslastung,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          S.of(context).dashboardAuslastungInfo(versorgt, gesamt),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Monatliche Uebersicht (Balkendiagramm) ──
          Text(
            S.of(context).dashboardMonatlicheUebersicht,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: monate.map((m) {
                    final barHeight =
                        maxMonat > 0 ? (m.anzahl / maxMonat) * 100 : 0.0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${m.anzahl}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: barHeight.toDouble().clamp(4.0, 100.0),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.7),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              m.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 60), // Platz fuer FAB
        ],
      ),
    );
  }

  static String _monatLabel(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    return labels[(month - 1) % 12];
  }
}

/// Hilfsdaten fuer das Balkendiagramm.
class _MonatDaten {
  final String label;
  final int anzahl;

  const _MonatDaten({required this.label, required this.anzahl});
}
