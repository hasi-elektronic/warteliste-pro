import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../models/patient.dart';
import '../../providers/patienten_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/patient_card.dart';

/// Haupt-Wartelisten-Screen mit Tabs, Suche, Filtern und Sortierung.
class WartelisteScreen extends ConsumerStatefulWidget {
  const WartelisteScreen({super.key});

  @override
  ConsumerState<WartelisteScreen> createState() => _WartelisteScreenState();
}

class _WartelisteScreenState extends ConsumerState<WartelisteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  static const List<PatientStatus?> _tabFilters = [
    null, // Alle
    PatientStatus.wartend,
    PatientStatus.platzGefunden,
    PatientStatus.inBehandlung,
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(wartelisteTabIndexProvider);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(wartelisteTabIndexProvider.notifier).state =
            _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSortDialog() {
    final current = ref.read(sortOptionProvider);
    final s = S.of(context);
    showDialog<SortOption>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(s.wartelisteSortierenNach),
        children: [
          _sortTile(s.wartelisteSortDatum, SortOption.datum, current),
          _sortTile(s.wartelisteSortName, SortOption.name, current),
          _sortTile(s.wartelisteSortWartezeit, SortOption.wartezeit, current),
          _sortTile(s.prioritaet, SortOption.prioritaet, current),
        ],
      ),
    ).then((value) {
      if (value != null) {
        ref.read(sortOptionProvider.notifier).state = value;
      }
    });
  }

  Widget _sortTile(String label, SortOption option, SortOption current) {
    return RadioListTile<SortOption>(
      title: Text(label),
      value: option,
      groupValue: current,
      onChanged: (value) => Navigator.pop(context, value),
    );
  }

  Future<void> _confirmDelete(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Patient loeschen?'),
        content: Text(
          'Moechten Sie ${patient.vollstaendigerName} wirklich '
          'von der Warteliste entfernen? '
          'Diese Aktion kann nicht rueckgaengig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Loeschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final service = ref.read(firebaseServiceProvider);
      await service.deletePatient(patient.praxisId, patient.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${patient.vollstaendigerName} geloescht'),
          ),
        );
      }
    }
  }

  Future<void> _changeStatus(Patient patient) async {
    final newStatus = await showDialog<PatientStatus>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Status aendern'),
        children: PatientStatus.values.map((status) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, status),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.statusColor(status.label),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(status.label),
                if (patient.status == status) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (newStatus != null && newStatus != patient.status && mounted) {
      final service = ref.read(firebaseServiceProvider);
      await service.updatePatientStatus(
        patient.praxisId,
        patient.id,
        newStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${patient.vollstaendigerName}: ${newStatus.label}',
            ),
          ),
        );
      }
    }
  }

  void _navigateToDetail(Patient patient) {
    Navigator.of(context).pushNamed(
      '/patient/detail',
      arguments: patient,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Externe Tab-Wechsel (z.B. ueber KPI-Karten im Dashboard) uebernehmen.
    ref.listen<int>(wartelisteTabIndexProvider, (prev, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });
    final s = S.of(context);
    return Column(
      children: [
        // ── Suchleiste ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: s.wartelistePatientSuchen,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
        ),

        // ── Filter-Chips ──
        _FilterChipsRow(),

        // ── Tabs ──
        Container(
          color: AppTheme.primaryColor,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.wartelisteAlle),
              Tab(text: s.statusWartend),
              Tab(text: s.statusPlatzGefunden),
              Tab(text: s.statusInBehandlung),
            ],
          ),
        ),

        // ── Sortier-Button ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final sort = ref.watch(sortOptionProvider);
                  return TextButton.icon(
                    onPressed: _showSortDialog,
                    icon: const Icon(Icons.sort, size: 18),
                    label: Text(
                      _sortLabel(sort, s),
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // ── Patientenliste ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _tabFilters.map((statusFilter) {
              return _PatientenListe(
                statusFilter: statusFilter,
                onTap: _navigateToDetail,
                onDelete: _confirmDelete,
                onStatusChanged: _changeStatus,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _sortLabel(SortOption option, S s) {
    switch (option) {
      case SortOption.datum:
        return s.wartelisteSortDatum;
      case SortOption.name:
        return s.wartelisteSortName;
      case SortOption.wartezeit:
        return s.wartelisteSortWartezeit;
      case SortOption.prioritaet:
        return s.prioritaet;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Filter-Chips
// ════════════════════════════════════════════════════════════════

class _FilterChipsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stoerungsbildFilter = ref.watch(stoerungsbildFilterProvider);
    final versicherungFilter = ref.watch(versicherungFilterProvider);
    final monatFilter = ref.watch(monatFilterProvider);

    final hasActiveFilter = stoerungsbildFilter != null ||
        versicherungFilter != null ||
        monatFilter != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Stoerungsbild-Filter
          _buildFilterChip(
            context: context,
            label: stoerungsbildFilter ?? 'Stoerungsbild',
            isActive: stoerungsbildFilter != null,
            onTap: () => _showStoerungsbildPicker(context, ref),
          ),
          const SizedBox(width: 8),

          // Versicherung-Filter
          _buildFilterChip(
            context: context,
            label: versicherungFilter ?? 'Versicherung',
            isActive: versicherungFilter != null,
            onTap: () => _showVersicherungPicker(context, ref),
          ),
          const SizedBox(width: 8),

          // Monat-Filter
          _buildFilterChip(
            context: context,
            label: monatFilter != null
                ? _formatMonat(monatFilter)
                : 'Monat',
            isActive: monatFilter != null,
            onTap: () => _showMonatPicker(context, ref),
          ),

          // Alle Filter zuruecksetzen
          if (hasActiveFilter) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.clear, size: 16),
              label: const Text('Alle Filter'),
              onPressed: () {
                ref.read(stoerungsbildFilterProvider.notifier).state = null;
                ref.read(versicherungFilterProvider.notifier).state = null;
                ref.read(monatFilterProvider.notifier).state = null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: isActive ? AppTheme.primaryColor : AppTheme.primaryColor,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
      side: BorderSide(
        color: AppTheme.primaryColor.withValues(alpha: 0.3),
      ),
    );
  }

  void _showStoerungsbildPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _BottomSheetList(
        title: 'Stoerungsbild waehlen',
        items: AppConstants.stoerungsbilder,
        selectedItem: ref.read(stoerungsbildFilterProvider),
        onSelected: (value) {
          ref.read(stoerungsbildFilterProvider.notifier).state = value;
          Navigator.pop(context);
        },
        onClear: () {
          ref.read(stoerungsbildFilterProvider.notifier).state = null;
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showVersicherungPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _BottomSheetList(
        title: 'Versicherung waehlen',
        items: AppConstants.versicherungsarten,
        selectedItem: ref.read(versicherungFilterProvider),
        onSelected: (value) {
          ref.read(versicherungFilterProvider.notifier).state = value;
          Navigator.pop(context);
        },
        onClear: () {
          ref.read(versicherungFilterProvider.notifier).state = null;
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showMonatPicker(BuildContext context, WidgetRef ref) {
    // Letzte 12 Monate generieren
    final now = DateTime.now();
    final monate = List.generate(12, (i) {
      final date = DateTime(now.year, now.month - i);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    });

    showModalBottomSheet(
      context: context,
      builder: (context) => _BottomSheetList(
        title: 'Monat waehlen',
        items: monate,
        selectedItem: ref.read(monatFilterProvider),
        itemLabelBuilder: _formatMonat,
        onSelected: (value) {
          ref.read(monatFilterProvider.notifier).state = value;
          Navigator.pop(context);
        },
        onClear: () {
          ref.read(monatFilterProvider.notifier).state = null;
          Navigator.pop(context);
        },
      ),
    );
  }

  static String _formatMonat(String monatKey) {
    try {
      final parts = monatKey.split('-');
      final month = int.parse(parts[1]);
      final year = parts[0];
      final monthNames = [
        'Januar', 'Februar', 'Maerz', 'April', 'Mai', 'Juni',
        'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
      ];
      return '${monthNames[month - 1]} $year';
    } catch (_) {
      return monatKey;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Bottom-Sheet-Liste fuer Filter
// ════════════════════════════════════════════════════════════════

class _BottomSheetList extends StatelessWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;
  final String Function(String)? itemLabelBuilder;

  const _BottomSheetList({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.onClear,
    this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (selectedItem != null)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Zuruecksetzen'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final label = itemLabelBuilder?.call(item) ?? item;
                final isSelected = item == selectedItem;
                return ListTile(
                  title: Text(label),
                  trailing: isSelected
                      ? Icon(Icons.check, color: AppTheme.primaryColor)
                      : null,
                  selected: isSelected,
                  onTap: () => onSelected(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Patientenliste (Tab-Inhalt)
// ════════════════════════════════════════════════════════════════

class _PatientenListe extends ConsumerWidget {
  final PatientStatus? statusFilter;
  final ValueChanged<Patient> onTap;
  final ValueChanged<Patient> onDelete;
  final ValueChanged<Patient> onStatusChanged;

  const _PatientenListe({
    required this.statusFilter,
    required this.onTap,
    required this.onDelete,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPatienten = ref.watch(gefiltertePatientenProvider);

    return asyncPatienten.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48,
                  color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(
                'Fehler beim Laden',
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
      ),
      data: (allPatienten) {
        // Zusaetzlich nach Tab-Status filtern
        final patienten = statusFilter == null
            ? allPatienten
            : allPatienten
                .where((p) => p.status == statusFilter)
                .toList();

        if (patienten.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keine Patienten auf der Warteliste',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tippen Sie auf "+", um einen neuen Patienten hinzuzufuegen.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Riverpod refresh
            ref.invalidate(patientenProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(
              top: 4,
              bottom: 80, // Platz fuer FAB
            ),
            itemCount: patienten.length,
            itemBuilder: (context, index) {
              final patient = patienten[index];
              return Dismissible(
                key: ValueKey(patient.id),
                background: _swipeBackground(
                  alignment: Alignment.centerLeft,
                  color: AppTheme.primaryColor,
                  icon: Icons.swap_horiz,
                  label: 'Status',
                ),
                secondaryBackground: _swipeBackground(
                  alignment: Alignment.centerRight,
                  color: AppTheme.errorColor,
                  icon: Icons.delete_outline,
                  label: 'Loeschen',
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    onDelete(patient);
                    return false; // Dialog handles deletion
                  } else {
                    onStatusChanged(patient);
                    return false; // Dialog handles status change
                  }
                },
                child: PatientCard(
                  patient: patient,
                  onTap: () => onTap(patient),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) ...[
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: color),
          if (alignment == Alignment.centerLeft) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
