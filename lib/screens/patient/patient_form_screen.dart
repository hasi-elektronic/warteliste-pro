import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/strings.dart';
import '../../models/patient.dart';
import '../../providers/patienten_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';

/// Formular zum Erstellen oder Bearbeiten eines Patienten.
///
/// Wenn [patient] uebergeben wird, wird das Formular im
/// Bearbeitungsmodus geoeffnet und alle Felder vorausgefuellt.
class PatientFormScreen extends ConsumerStatefulWidget {
  final Patient? patient;

  const PatientFormScreen({
    super.key,
    this.patient,
  });

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controller
  late final TextEditingController _vornameController;
  late final TextEditingController _nameController;
  late final TextEditingController _telefonController;
  late final TextEditingController _adresseController;
  late final TextEditingController _arztController;
  late final TextEditingController _weitereInfosController;
  late final TextEditingController _sonstigeStoerungController;
  late final TextEditingController _verordnungsMengeController;

  // State
  late String _versicherung;
  late String? _stoerungsbild;
  late String _terminWunsch;
  DateTime? _geburtsdatum;
  DateTime? _rezeptDatum;
  DateTime? _rezeptGueltigBis;
  late PatientPrioritaet _prioritaet;
  bool _showSonstigeStoerung = false;

  bool get _isEditing => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;

    _vornameController = TextEditingController(text: p?.vorname ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _telefonController = TextEditingController(text: p?.telefon ?? '');
    _adresseController = TextEditingController(text: p?.adresse ?? '');
    _arztController = TextEditingController(text: p?.arzt ?? '');
    _weitereInfosController =
        TextEditingController(text: p?.weitereInfos ?? '');
    _sonstigeStoerungController = TextEditingController();
    _verordnungsMengeController = TextEditingController(
      text: p?.verordnungsMenge?.toString() ?? '',
    );

    _versicherung = p?.versicherung ?? AppConstants.versicherungKK;
    _terminWunsch = p?.terminWunsch ?? AppConstants.terminFlexibel;
    _geburtsdatum = p?.geburtsdatum;
    _rezeptDatum = p?.rezeptDatum;
    _rezeptGueltigBis = p?.rezeptGueltigBis;
    _prioritaet = p?.prioritaet ?? PatientPrioritaet.normal;

    // Stoerungsbild: wenn vorhandener Wert nicht in der Liste ist,
    // als "Sonstige" behandeln.
    if (p != null && p.stoerungsbild.isNotEmpty) {
      if (AppConstants.stoerungsbilder.contains(p.stoerungsbild)) {
        _stoerungsbild = p.stoerungsbild;
      } else {
        _stoerungsbild = '_sonstige';
        _sonstigeStoerungController.text = p.stoerungsbild;
        _showSonstigeStoerung = true;
      }
    } else {
      _stoerungsbild = null;
    }

    // Terminwunsch: Wenn der Wert nicht in den Standardoptionen
    // enthalten ist, als Custom behandeln.
    if (p != null &&
        !AppConstants.terminOptionen.contains(p.terminWunsch) &&
        p.terminWunsch.isNotEmpty) {
      _terminWunsch = p.terminWunsch;
    }
  }

  @override
  void dispose() {
    _vornameController.dispose();
    _nameController.dispose();
    _telefonController.dispose();
    _adresseController.dispose();
    _arztController.dispose();
    _weitereInfosController.dispose();
    _sonstigeStoerungController.dispose();
    _verordnungsMengeController.dispose();
    super.dispose();
  }

  String get _resolvedStoerungsbild {
    if (_stoerungsbild == '_sonstige') {
      return _sonstigeStoerungController.text.trim();
    }
    return _stoerungsbild ?? '';
  }

  Future<void> _pickGeburtsdatum() async {
    final s = S.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _geburtsdatum ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: s.geburtsdatumWaehlen,
    );
    if (picked != null) {
      setState(() => _geburtsdatum = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(firebaseServiceProvider);
      final praxisId = ref.read(praxisIdProvider);

      if (praxisId == null || praxisId.isEmpty) {
        throw Exception('Keine Praxis-ID gefunden. Bitte erneut anmelden.');
      }

      final now = DateTime.now();
      final monatStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final verordnungsMenge = int.tryParse(
        _verordnungsMengeController.text.trim(),
      );

      if (_isEditing) {
        // Bestehenden Patienten aktualisieren
        final updated = widget.patient!.copyWith(
          vorname: _vornameController.text.trim(),
          name: _nameController.text.trim(),
          telefon: _telefonController.text.trim(),
          adresse: _adresseController.text.trim(),
          stoerungsbild: _resolvedStoerungsbild,
          versicherung: _versicherung,
          arzt: _arztController.text.trim(),
          terminWunsch: _terminWunsch,
          weitereInfos: _weitereInfosController.text.trim(),
          geburtsdatum: _geburtsdatum,
          clearGeburtsdatum: _geburtsdatum == null &&
              widget.patient!.geburtsdatum != null,
          rezeptDatum: _rezeptDatum,
          clearRezeptDatum: _rezeptDatum == null &&
              widget.patient!.rezeptDatum != null,
          rezeptGueltigBis: _rezeptGueltigBis,
          clearRezeptGueltigBis: _rezeptGueltigBis == null &&
              widget.patient!.rezeptGueltigBis != null,
          verordnungsMenge: verordnungsMenge,
          clearVerordnungsMenge: verordnungsMenge == null &&
              widget.patient!.verordnungsMenge != null,
          prioritaet: _prioritaet,
        );
        await service.updatePatient(updated);
      } else {
        // Neuen Patienten erstellen
        final newPatient = Patient(
          id: '',
          anmeldung: now,
          name: _nameController.text.trim(),
          vorname: _vornameController.text.trim(),
          telefon: _telefonController.text.trim(),
          adresse: _adresseController.text.trim(),
          stoerungsbild: _resolvedStoerungsbild,
          versicherung: _versicherung,
          arzt: _arztController.text.trim(),
          terminWunsch: _terminWunsch,
          weitereInfos: _weitereInfosController.text.trim(),
          geburtsdatum: _geburtsdatum,
          monat: monatStr,
          praxisId: praxisId,
          rezeptDatum: _rezeptDatum,
          rezeptGueltigBis: _rezeptGueltigBis,
          verordnungsMenge: verordnungsMenge,
          prioritaet: _prioritaet,
        );
        await service.addPatient(newPatient);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient gespeichert')),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');
    final s = S.of(context);
    final isDe = s.isGerman;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.patientBearbeitenTitel : s.patientNeuerTitel),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Persoenliche Daten ──
            _SectionHeader(
                title: isDe ? 'Persönliche Daten' : 'Personal data'),
            const SizedBox(height: 8),

            // Vorname
            TextFormField(
              controller: _vornameController,
              decoration: InputDecoration(
                labelText: '${s.labelVorname} *',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return isDe
                      ? 'Bitte Vornamen eingeben'
                      : 'Please enter first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Name (Nachname)
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '${s.labelName} *',
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return isDe
                      ? 'Bitte Nachnamen eingeben'
                      : 'Please enter last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Telefon
            TextFormField(
              controller: _telefonController,
              decoration: InputDecoration(
                labelText: '${s.labelTelefon} *',
                prefixIcon: const Icon(Icons.phone_outlined),
                hintText: 'z.B. 0711/1234567',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return isDe
                      ? 'Bitte Telefonnummer eingeben'
                      : 'Please enter phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Adresse
            TextFormField(
              controller: _adresseController,
              decoration: InputDecoration(
                labelText: isDe ? 'Adresse' : 'Address',
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Geburtsdatum
            InkWell(
              onTap: _pickGeburtsdatum,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: s.labelGeburtsdatum,
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixIcon: _geburtsdatum != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() => _geburtsdatum = null);
                          },
                        )
                      : const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _geburtsdatum != null
                      ? dateFormat.format(_geburtsdatum!)
                      : s.datumWaehlen,
                  style: TextStyle(
                    color: _geburtsdatum != null
                        ? theme.textTheme.bodyLarge?.color
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Medizinische Daten ──
            _SectionHeader(
                title: isDe ? 'Medizinische Daten' : 'Medical data'),
            const SizedBox(height: 8),

            // Stoerungsbild
            DropdownButtonFormField<String>(
              value: _stoerungsbild,
              decoration: InputDecoration(
                labelText: s.labelStoerungsbild,
                prefixIcon: const Icon(Icons.medical_services_outlined),
              ),
              items: [
                ...AppConstants.stoerungsbilder.map(
                  (st) => DropdownMenuItem(value: st, child: Text(st)),
                ),
                DropdownMenuItem(
                  value: '_sonstige',
                  child: Text(isDe ? 'Sonstige...' : 'Other...'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _stoerungsbild = value;
                  _showSonstigeStoerung = value == '_sonstige';
                });
              },
            ),
            if (_showSonstigeStoerung) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _sonstigeStoerungController,
                decoration: InputDecoration(
                  labelText: isDe
                      ? 'Störungsbild (Freitext)'
                      : 'Diagnosis (free text)',
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 12),

            // Versicherung
            Text(
              s.labelVersicherung,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'KK',
                  label: Text(isDe ? 'Krankenkasse' : 'Public'),
                  icon: const Icon(Icons.account_balance_outlined),
                ),
                ButtonSegment(
                  value: 'Privat',
                  label: Text(isDe ? 'Privat' : 'Private'),
                  icon: const Icon(Icons.shield_outlined),
                ),
              ],
              selected: {_versicherung},
              onSelectionChanged: (selection) {
                setState(() => _versicherung = selection.first);
              },
            ),
            const SizedBox(height: 12),

            // Arzt
            TextFormField(
              controller: _arztController,
              decoration: InputDecoration(
                labelText: isDe ? 'Verordnender Arzt' : 'Prescribing doctor',
                prefixIcon: const Icon(Icons.local_hospital_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // ── Terminwunsch ──
            _SectionHeader(
                title: isDe ? 'Terminwunsch' : 'Preferred appointment'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppConstants.terminOptionen.map((option) {
                final isSelected = _terminWunsch == option;
                return ChoiceChip(
                  label: Text(_terminLabel(option, s)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _terminWunsch = option);
                    }
                  },
                  selectedColor:
                      AppTheme.primaryColor.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Rezept / Verordnung ──
            _SectionHeader(title: s.rezeptTitel),
            const SizedBox(height: 8),

            // Rezept-Datum
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _rezeptDatum ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  helpText: s.rezeptDatum,
                );
                if (picked != null) setState(() => _rezeptDatum = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: s.rezeptDatum,
                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                  suffixIcon: _rezeptDatum != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => _rezeptDatum = null),
                        )
                      : const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _rezeptDatum != null
                      ? dateFormat.format(_rezeptDatum!)
                      : s.datumWaehlen,
                  style: TextStyle(
                    color: _rezeptDatum != null
                        ? theme.textTheme.bodyLarge?.color
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Gueltig bis
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _rezeptGueltigBis ??
                      (_rezeptDatum?.add(const Duration(days: 28)) ??
                          DateTime.now().add(const Duration(days: 28))),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  helpText: s.rezeptGueltigBis,
                );
                if (picked != null) {
                  setState(() => _rezeptGueltigBis = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: s.rezeptGueltigBis,
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: _rezeptGueltigBis != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => _rezeptGueltigBis = null),
                        )
                      : const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _rezeptGueltigBis != null
                      ? dateFormat.format(_rezeptGueltigBis!)
                      : s.datumWaehlen,
                  style: TextStyle(
                    color: _rezeptGueltigBis != null
                        ? theme.textTheme.bodyLarge?.color
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Verordnungsmenge
            TextFormField(
              controller: _verordnungsMengeController,
              decoration: InputDecoration(
                labelText: s.rezeptVerordnungsMenge,
                prefixIcon: const Icon(Icons.format_list_numbered),
                hintText: isDe ? 'z.B. 10' : 'e.g. 10',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // ── Prioritaet ──
            _SectionHeader(title: s.prioritaet),
            const SizedBox(height: 8),
            SegmentedButton<PatientPrioritaet>(
              segments: [
                ButtonSegment(
                  value: PatientPrioritaet.normal,
                  label: Text(s.prioritaetNormal),
                ),
                ButtonSegment(
                  value: PatientPrioritaet.hoch,
                  label: Text(s.prioritaetHoch),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                ),
                ButtonSegment(
                  value: PatientPrioritaet.dringend,
                  label: Text(s.prioritaetDringend),
                  icon: const Icon(Icons.priority_high, size: 16),
                ),
              ],
              selected: {_prioritaet},
              onSelectionChanged: (selection) {
                setState(() => _prioritaet = selection.first);
              },
            ),
            const SizedBox(height: 24),

            // ── Weitere Infos ──
            _SectionHeader(
                title: isDe ? 'Weitere Informationen' : 'Additional information'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weitereInfosController,
              decoration: InputDecoration(
                labelText: s.labelWeitereInfos,
                prefixIcon: const Icon(Icons.note_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),

            // ── Speichern-Button ──
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isLoading
                      ? (isDe ? 'Speichert...' : 'Saving...')
                      : s.speichern,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _terminLabel(String option, S s) {
    switch (option) {
      case 'flexibel':
        return s.isGerman ? 'Flexibel' : 'Flexible';
      case 'vormittags':
        return s.isGerman ? 'Vormittags' : 'Mornings';
      case 'nachmittags':
        return s.isGerman ? 'Nachmittags' : 'Afternoons';
      default:
        return option;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Sektions-Header
// ════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
