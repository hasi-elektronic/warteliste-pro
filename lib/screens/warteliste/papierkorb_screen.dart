import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/patient.dart';
import '../../providers/patienten_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/app_header.dart';

/// Papierkorb: zeigt soft-geloeschte Patienten. Wiederherstellen oder
/// endgueltig loeschen.
class PapierkorbScreen extends ConsumerWidget {
  const PapierkorbScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(geloeschtePatientenProvider);
    final fmt = DateFormat('dd.MM.yyyy · HH:mm');

    return Scaffold(
      appBar: const AppHeader(title: 'Papierkorb', showBackButton: true),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (patienten) {
          if (patienten.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline,
                      size: 56, color: AppTheme.slate300),
                  const SizedBox(height: 12),
                  Text('Papierkorb ist leer',
                      style: TextStyle(color: AppTheme.slate500)),
                  const SizedBox(height: 4),
                  Text(
                    'Geloeschte Patienten erscheinen hier und\n'
                    'koennen wiederhergestellt werden.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.slate400, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${patienten.length} Patient(en) im Papierkorb. '
                        'Wiederherstellen oder endgueltig loeschen.',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              ...patienten.map((p) => _PapierkorbTile(patient: p, fmt: fmt)),
            ],
          );
        },
      ),
    );
  }
}

class _PapierkorbTile extends ConsumerWidget {
  final Patient patient;
  final DateFormat fmt;
  const _PapierkorbTile({required this.patient, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.vollstaendigerName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (patient.stoerungsbild.isNotEmpty)
                        patient.stoerungsbild,
                      if (patient.geloeschtAm != null)
                        'geloescht: ${fmt.format(patient.geloeschtAm!)}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Wiederherstellen',
              icon: Icon(Icons.restore, color: AppTheme.primaryColor),
              onPressed: () async {
                await ref.read(firebaseServiceProvider).restorePatient(
                      patient.praxisId,
                      patient.id,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${patient.vollstaendigerName} wiederhergestellt')),
                  );
                }
              },
            ),
            IconButton(
              tooltip: 'Endgueltig loeschen',
              icon: Icon(Icons.delete_forever, color: AppTheme.errorColor),
              onPressed: () => _confirmPermanent(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPermanent(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Endgueltig loeschen?'),
        content: Text(
          '"${patient.vollstaendigerName}" wird unwiderruflich geloescht. '
          'Diese Aktion kann NICHT rueckgaengig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Endgueltig loeschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(firebaseServiceProvider).deletePatientPermanent(
            patient.praxisId,
            patient.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endgueltig geloescht')),
        );
      }
    }
  }
}
