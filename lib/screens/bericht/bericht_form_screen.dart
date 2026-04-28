import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/bericht.dart';
import '../../models/patient.dart';
import '../../providers/patienten_provider.dart';
import '../../providers/standort_provider.dart';
import '../../services/bericht_pdf_service.dart';
import '../../utils/theme.dart';
import '../../widgets/app_header.dart';

/// Argumente fuer das Bericht-Formular.
class BerichtFormArgs {
  /// Falls vorhanden: Bericht zum Bearbeiten.
  final Bericht? bericht;

  /// Falls vorhanden: zugehoeriger Patient (vorab ausgewaehlt).
  final Patient? patient;

  /// Vorgewaehlte Kategorie.
  final BerichtKategorie? kategorie;

  const BerichtFormArgs({this.bericht, this.patient, this.kategorie});
}

class BerichtFormScreen extends ConsumerStatefulWidget {
  final BerichtFormArgs args;
  const BerichtFormScreen({super.key, required this.args});

  @override
  ConsumerState<BerichtFormScreen> createState() => _BerichtFormScreenState();
}

class _BerichtFormScreenState extends ConsumerState<BerichtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titelCtrl;
  late final TextEditingController _inhaltCtrl;
  late BerichtKategorie _kategorie;
  Patient? _patient; // optional patient
  bool _saving = false;

  bool get _isEditing => widget.args.bericht != null;

  @override
  void initState() {
    super.initState();
    final b = widget.args.bericht;
    _titelCtrl = TextEditingController(text: b?.titel ?? '');
    final defaultKategorie = widget.args.kategorie ??
        (widget.args.patient != null
            ? BerichtKategorie.verlaufsbericht
            : BerichtKategorie.allgemein);
    _inhaltCtrl = TextEditingController(
      text: b?.inhalt ?? defaultKategorie.vorlage,
    );
    _kategorie = b?.kategorie ??
        widget.args.kategorie ??
        (widget.args.patient != null
            ? BerichtKategorie.verlaufsbericht
            : BerichtKategorie.allgemein);
    _patient = widget.args.patient;
    if (b?.patientId != null) {
      // Bericht editiert mit Patient — wird ueber Provider nachgeladen
    }
  }

  @override
  void dispose() {
    _titelCtrl.dispose();
    _inhaltCtrl.dispose();
    super.dispose();
  }

  Future<void> _printPdf() async {
    if (widget.args.bericht == null) return;
    try {
      final praxis = ref.read(aktivesPraxisProvider);
      // Aktuelle (evtl. ungespeicherte) Werte aus Form nehmen
      final aktuell = widget.args.bericht!.copyWith(
        titel: _titelCtrl.text.trim(),
        inhalt: _inhaltCtrl.text.trim(),
        kategorie: _kategorie,
      );
      await BerichtPdfService.druckeBericht(
        bericht: aktuell,
        praxisName: praxis?.name ?? 'WarteListe Pro',
        praxisAdresse: praxis?.adresse ?? '',
        praxisTelefon: praxis?.telefon ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF-Export fehlgeschlagen: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _applyVorlage(BerichtKategorie k) {
    setState(() {
      _kategorie = k;
      // Inhalt nur ersetzen wenn er leer ist oder die alte Vorlage entspricht
      final aktuell = _inhaltCtrl.text.trim();
      final alteVorlagen =
          BerichtKategorie.values.map((e) => e.vorlage.trim()).toSet();
      if (aktuell.isEmpty || alteVorlagen.contains(aktuell)) {
        _inhaltCtrl.text = k.vorlage;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final svc = ref.read(berichtServiceProvider);
      final praxisId = ref.read(praxisIdProvider);
      final user = FirebaseAuth.instance.currentUser;

      if (praxisId == null || user == null) {
        throw Exception('Nicht angemeldet');
      }

      if (_isEditing) {
        final updated = widget.args.bericht!.copyWith(
          titel: _titelCtrl.text.trim(),
          inhalt: _inhaltCtrl.text.trim(),
          kategorie: _kategorie,
          aktualisiertAm: DateTime.now(),
        );
        await svc.updateBericht(updated);
      } else {
        final bericht = Bericht(
          id: '',
          praxisId: praxisId,
          patientId: _patient?.id,
          patientName: _patient?.vollstaendigerName,
          authorUid: user.uid,
          authorEmail: user.email ?? '',
          authorName: user.displayName,
          erstelltAm: DateTime.now(),
          kategorie: _kategorie,
          titel: _titelCtrl.text.trim(),
          inhalt: _inhaltCtrl.text.trim(),
        );
        await svc.addBericht(bericht);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bericht gespeichert')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: _isEditing ? 'Bericht bearbeiten' : 'Neuer Bericht',
        icon: _isEditing
            ? Icons.edit_note_outlined
            : Icons.note_add_outlined,
        showBackButton: true,
        actions: _isEditing
            ? [
                HeaderIconAction(
                  icon: Icons.picture_as_pdf_outlined,
                  tooltip: 'Als PDF drucken',
                  onTap: () => _printPdf(),
                ),
                const SizedBox(width: 4),
              ]
            : const [],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Vorlage / Kategorie ──
            Text(
              'Vorlage wählen',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BerichtKategorie.values
                  .map((k) => _VorlageChip(
                        kategorie: k,
                        selected: _kategorie == k,
                        onTap: () => _applyVorlage(k),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ── Patient-Info (read-only wenn vorgewählt) ──
            if (_patient != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bezogen auf Patient',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.slate600,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            _patient!.vollstaendigerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isEditing && widget.args.patient == null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _patient = null),
                        tooltip: 'Patient entfernen',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Titel ──
            TextFormField(
              controller: _titelCtrl,
              decoration: const InputDecoration(
                labelText: 'Titel / Betreff *',
                prefixIcon: Icon(Icons.title_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Bitte einen Titel eingeben';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Inhalt ──
            TextFormField(
              controller: _inhaltCtrl,
              decoration: const InputDecoration(
                labelText: 'Inhalt *',
                alignLabelWithHint: true,
                hintText: 'Schreiben Sie hier den Bericht …',
              ),
              minLines: 12,
              maxLines: 30,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Bitte einen Inhalt eingeben';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Speichern ──
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Speichert …' : 'Bericht speichern'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Chip zum Auswaehlen einer Vorlage.
class _VorlageChip extends StatelessWidget {
  final BerichtKategorie kategorie;
  final bool selected;
  final VoidCallback onTap;

  const _VorlageChip({
    required this.kategorie,
    required this.selected,
    required this.onTap,
  });

  IconData _iconFor(BerichtKategorie k) {
    switch (k) {
      case BerichtKategorie.verlaufsbericht:
        return Icons.trending_up;
      case BerichtKategorie.anamnese:
        return Icons.history_edu_outlined;
      case BerichtKategorie.telefonat:
        return Icons.phone_in_talk_outlined;
      case BerichtKategorie.uebergabe:
        return Icons.change_circle_outlined;
      case BerichtKategorie.allgemein:
        return Icons.sticky_note_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.slate300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconFor(kategorie),
                  size: 18,
                  color: selected ? Colors.white : AppTheme.slate700),
              const SizedBox(width: 8),
              Text(
                kategorie.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.slate800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
