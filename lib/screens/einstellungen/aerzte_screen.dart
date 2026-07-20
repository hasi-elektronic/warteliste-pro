import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/arzt.dart';
import '../../providers/patienten_provider.dart';
import '../../utils/theme.dart';

/// Verwaltung des Praxis-Adressbuchs der Aerzte (anlegen, bearbeiten, loeschen).
///
/// Route: `/aerzte`
class AerzteScreen extends ConsumerWidget {
  const AerzteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aerzteAsync = ref.watch(aerzteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ärzte-Adressbuch'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Arzt'),
      ),
      body: aerzteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Fehler beim Laden: $e'),
          ),
        ),
        data: (aerzte) {
          if (aerzte.isEmpty) {
            return _EmptyState(onAdd: () => _openForm(context, ref));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: aerzte.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _ArztTile(
              arzt: aerzte[i],
              onEdit: () => _openForm(context, ref, existing: aerzte[i]),
              onDelete: () => _delete(context, ref, aerzte[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {Arzt? existing}) async {
    final praxisId = ref.read(praxisIdProvider);
    if (praxisId == null || praxisId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine aktive Praxis')),
      );
      return;
    }

    final result = await showDialog<Arzt>(
      context: context,
      builder: (ctx) => _ArztFormDialog(existing: existing, praxisId: praxisId),
    );
    if (result == null) return;

    final service = ref.read(firebaseServiceProvider);
    try {
      if (existing == null) {
        await service.addArzt(result);
      } else {
        await service.updateArzt(result);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null
                ? 'Arzt hinzugefügt'
                : 'Arzt aktualisiert'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Arzt arzt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arzt löschen?'),
        content: Text('„${arzt.name}" wirklich aus dem Adressbuch löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(firebaseServiceProvider).deleteArzt(arzt.praxisId, arzt.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arzt gelöscht')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

class _ArztTile extends StatelessWidget {
  final Arzt arzt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ArztTile({
    required this.arzt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adresse = [
      arzt.strasse,
      [arzt.plz, arzt.ort].where((e) => e.trim().isNotEmpty).join(' '),
    ].where((e) => e.trim().isNotEmpty).join(', ');

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 12),
                child: Icon(Icons.local_hospital_outlined,
                    color: AppTheme.primaryColor),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arzt.name.isEmpty ? '(ohne Namen)' : arzt.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (arzt.fachrichtung.trim().isNotEmpty)
                      Text(arzt.fachrichtung,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppTheme.slate500)),
                    if (adresse.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(adresse,
                            style: theme.textTheme.bodySmall),
                      ),
                    if (arzt.telefon.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Tel. ${arzt.telefon}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppTheme.slate500)),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                  PopupMenuItem(value: 'delete', child: Text('Löschen')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_hospital_outlined,
                size: 56, color: AppTheme.slate400),
            const SizedBox(height: 16),
            Text('Noch keine Ärzte im Adressbuch',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Legen Sie Ärzte einmal an — danach können Sie sie in Briefen '
              'per Klick als Empfänger einfügen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.slate500),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ersten Arzt anlegen'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formular-Dialog zum Anlegen/Bearbeiten eines Arztes.
class _ArztFormDialog extends StatefulWidget {
  final Arzt? existing;
  final String praxisId;

  const _ArztFormDialog({required this.existing, required this.praxisId});

  @override
  State<_ArztFormDialog> createState() => _ArztFormDialogState();
}

class _ArztFormDialogState extends State<_ArztFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _fachrichtung;
  late final TextEditingController _strasse;
  late final TextEditingController _plz;
  late final TextEditingController _ort;
  late final TextEditingController _telefon;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _name = TextEditingController(text: a?.name ?? '');
    _fachrichtung = TextEditingController(text: a?.fachrichtung ?? '');
    _strasse = TextEditingController(text: a?.strasse ?? '');
    _plz = TextEditingController(text: a?.plz ?? '');
    _ort = TextEditingController(text: a?.ort ?? '');
    _telefon = TextEditingController(text: a?.telefon ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _fachrichtung.dispose();
    _strasse.dispose();
    _plz.dispose();
    _ort.dispose();
    _telefon.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.existing;
    final arzt = (base ?? Arzt(id: '', name: '', praxisId: widget.praxisId))
        .copyWith(
      name: _name.text.trim(),
      fachrichtung: _fachrichtung.text.trim(),
      strasse: _strasse.text.trim(),
      plz: _plz.text.trim(),
      ort: _ort.text.trim(),
      telefon: _telefon.text.trim(),
    );
    Navigator.of(context).pop(arzt);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Arzt hinzufügen' : 'Arzt bearbeiten'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'z. B. Dr. med. Anna Weber',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bitte Namen eingeben' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _fachrichtung,
                decoration: const InputDecoration(
                  labelText: 'Fachrichtung',
                  hintText: 'z. B. HNO, Kinderarzt',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _strasse,
                decoration: const InputDecoration(labelText: 'Straße & Nr.'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _plz,
                      decoration: const InputDecoration(labelText: 'PLZ'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _ort,
                      decoration: const InputDecoration(labelText: 'Ort'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telefon,
                decoration: const InputDecoration(labelText: 'Telefon'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
