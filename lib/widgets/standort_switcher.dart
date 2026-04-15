import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/praxis.dart';
import '../providers/auth_provider.dart';
import '../providers/patienten_provider.dart';
import '../providers/standort_provider.dart';
import '../utils/theme.dart';

/// Inline Standort-Switcher mit Expand/Collapse Dropdown.
///
/// Zeigt den aktuellen Standort. Bei Tap klappt die Liste
/// direkt darunter auf — kein Dialog, kein BottomSheet.
class StandortSwitcher extends ConsumerStatefulWidget {
  const StandortSwitcher({super.key});

  @override
  ConsumerState<StandortSwitcher> createState() => _StandortSwitcherState();
}

class _StandortSwitcherState extends ConsumerState<StandortSwitcher> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final aktivePraxis = ref.watch(aktivesPraxisProvider);
    final standorteAsync = ref.watch(standorteProvider);

    if (!isAdmin) return const SizedBox.shrink();
    if (aktivePraxis == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header (aktueller Standort) ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aktivePraxis.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Dropdown Liste ──
          if (_expanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: standorteAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Fehler: $e', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                ),
                data: (standorte) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...standorte.map((praxis) {
                      final isActive = praxis.id == aktivePraxis.id;
                      return InkWell(
                        onTap: isActive
                            ? () => setState(() => _expanded = false)
                            : () => _switchStandort(praxis),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                size: 16,
                                color: isActive ? AppTheme.primaryColor : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      praxis.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                        color: isActive ? AppTheme.primaryColor : null,
                                      ),
                                    ),
                                    if (praxis.adresse.isNotEmpty)
                                      Text(
                                        praxis.adresse,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              if (isActive)
                                Icon(Icons.check, size: 16, color: AppTheme.primaryColor),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _switchStandort(Praxis praxis) async {
    setState(() => _expanded = false);
    final service = ref.read(firebaseServiceProvider);
    await service.switchStandort(praxis.id);
    if (mounted) {
      ref.read(praxisIdProvider.notifier).state = praxis.id;
    }
  }
}
