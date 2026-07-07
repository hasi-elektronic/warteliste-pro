import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/strings.dart';
import '../../models/patient.dart';
import '../../models/therapeut.dart';
import '../../providers/patienten_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/app_header.dart';

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
  late final TextEditingController _kkSonstigesController;

  // State
  late String _versicherung;
  late String? _stoerungsbild;
  late String _terminWunsch;
  late DateTime _anmeldung;
  DateTime? _geburtsdatum;
  DateTime? _rezeptDatum;
  DateTime? _rezeptGueltigBis;
  late PatientPrioritaet _prioritaet;
  bool _showSonstigeStoerung = false;
  bool _hausbesuch = false;
  String? _therapeutId;
  List<Therapeut> _therapeuten = [];

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
    _kkSonstigesController =
        TextEditingController(text: p?.kkSonstiges ?? '');

    _versicherung = p?.versicherung ?? AppConstants.versicherungKK;
    _terminWunsch = p?.terminWunsch ?? AppConstants.terminFlexibel;
    _anmeldung = p?.anmeldung ?? DateTime.now();
    _geburtsdatum = p?.geburtsdatum;
    _rezeptDatum = p?.rezeptDatum;
    _rezeptGueltigBis = p?.rezeptGueltigBis;
    _prioritaet = p?.prioritaet ?? PatientPrioritaet.normal;
    _hausbesuch = p?.hausbesuch ?? false;
    _therapeutId = p?.therapeutId;

    // Therapeuten laden (async)
    _loadTherapeuten();

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
    _kkSonstigesController.dispose();
    super.dispose();
  }

  Future<void> _loadTherapeuten() async {
    final praxisId = ref.read(praxisIdProvider);
    if (praxisId == null) return;
    final service = ref.read(firebaseServiceProvider);
    service.getTherapeuten(praxisId).first.then((list) {
      if (mounted) setState(() => _therapeuten = list);
    }).catchError((_) {});
  }

  Future<void> _pickAnmeldedatum() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anmeldung,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Anmeldedatum wählen',
    );
    if (picked != null) {
      setState(() => _anmeldung = picked);
    }
  }

  /// Prueft auf moegliche Duplikate (gleicher Name + Vorname + Geburtsdatum).
  /// Gibt true zurueck wenn der User trotz Duplikat speichern moechte.
  Future<bool> _confirmDuplicateIfNeeded() async {
    if (_isEditing) return true; // beim Bearbeiten kein Check

    final praxisId = ref.read(praxisIdProvider);
    if (praxisId == null) return true;
    final all = ref.read(patientenProvider).value ?? const [];

    final vor = _vornameController.text.trim().toLowerCase();
    final nam = _nameController.text.trim().toLowerCase();
    if (vor.isEmpty || nam.isEmpty) return true;

    final matches = all.where((p) {
      if (p.vorname.toLowerCase() != vor) return false;
      if (p.name.toLowerCase() != nam) return false;
      if (_geburtsdatum != null && p.geburtsdatum != null) {
        return p.geburtsdatum!.year == _geburtsdatum!.year &&
            p.geburtsdatum!.month == _geburtsdatum!.month &&
            p.geburtsdatum!.day == _geburtsdatum!.day;
      }
      return true; // bei fehlendem Geburtsdatum nur Namensvergleich
    }).toList();

    if (matches.isEmpty) return true;

    if (!mounted) return true;
    final fmt = DateFormat('dd.MM.yyyy');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppTheme.warningColor, size: 36),
        title: const Text('Mögliches Duplikat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Es existiert bereits ein Patient mit demselben Namen:',
            ),
            const SizedBox(height: 12),
            ...matches.take(3).map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${p.vollstaendigerName}'
                          '${p.geburtsdatum != null ? " (${fmt.format(p.geburtsdatum!)})" : ""} '
                          '— ${p.status.label}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            const Text(
              'Trotzdem als neuen Patient speichern?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warningColor),
            child: const Text('Trotzdem speichern'),
          ),
        ],
      ),
    );
    return result == true;
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

    // Duplicate-Check (nur bei neuem Patient)
    final ok = await _confirmDuplicateIfNeeded();
    if (!ok) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(firebaseServiceProvider);
      final praxisId = ref.read(praxisIdProvider);

      if (praxisId == null || praxisId.isEmpty) {
        throw Exception('Keine Praxis-ID gefunden. Bitte erneut anmelden.');
      }

      final monatStr =
          '${_anmeldung.year}-${_anmeldung.month.toString().padLeft(2, '0')}';

      final verordnungsMenge = int.tryParse(
        _verordnungsMengeController.text.trim(),
      );

      // Wenn Versicherung != Sonstiges, kkSonstiges leeren
      final kkSonstiges = _versicherung == AppConstants.versicherungSonstiges
          ? _kkSonstigesController.text.trim()
          : '';

      if (_isEditing) {
        // Bestehenden Patienten aktualisieren
        final updated = widget.patient!.copyWith(
          anmeldung: _anmeldung,
          monat: monatStr,
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
          hausbesuch: _hausbesuch,
          kkSonstiges: kkSonstiges,
          therapeutId: _therapeutId,
          clearTherapeutId: _therapeutId == null &&
              widget.patient!.therapeutId != null,
        );
        await service.updatePatient(updated);
      } else {
        // Neuen Patienten erstellen
        final newPatient = Patient(
          id: '',
          anmeldung: _anmeldung,
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
          hausbesuch: _hausbesuch,
          kkSonstiges: kkSonstiges,
          therapeutId: _therapeutId,
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
      appBar: AppHeader(
        title: _isEditing ? s.patientBearbeitenTitel : s.patientNeuerTitel,
        icon: _isEditing ? Icons.edit_outlined : Icons.person_add_outlined,
        showBackButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Anmeldedatum ──
            _SectionHeader(
                title: isDe ? 'Anmeldedatum' : 'Registration date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickAnmeldedatum,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isDe ? 'Anmeldedatum' : 'Registration date',
                  prefixIcon: const Icon(Icons.event_note_outlined),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                  helperText: isDe
                      ? 'Standard: heute. Bei Übertragung der Papierliste anpassbar.'
                      : 'Default: today. Editable when transferring paper list.',
                ),
                child: Text(
                  dateFormat.format(_anmeldung),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),

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
                  icon: const Icon(Icons.account_balance_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 'Privat',
                  label: Text(isDe ? 'Privat' : 'Private'),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                ),
                ButtonSegment(
                  value: AppConstants.versicherungJugendamt,
                  label: Text(isDe ? 'Jugendamt' : 'Youth Office'),
                  icon: const Icon(Icons.family_restroom_outlined, size: 16),
                ),
                ButtonSegment(
                  value: AppConstants.versicherungSonstiges,
                  label: Text(isDe ? 'Sonstiges' : 'Other'),
                  icon: const Icon(Icons.more_horiz, size: 16),
                ),
              ],
              selected: {_versicherung},
              onSelectionChanged: (selection) {
                setState(() => _versicherung = selection.first);
              },
            ),
            if (_versicherung == AppConstants.versicherungSonstiges) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _kkSonstigesController,
                decoration: InputDecoration(
                  labelText: isDe ? 'Bezeichnung' : 'Description',
                  hintText: 'BG, PBeaKK, ...',
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (_versicherung == AppConstants.versicherungSonstiges &&
                      (v == null || v.trim().isEmpty)) {
                    return isDe
                        ? 'Bitte Bezeichnung eingeben'
                        : 'Please enter description';
                  }
                  return null;
                },
              ),
            ],
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
            const SizedBox(height: 16),

            // Hausbesuch
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.slate300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                value: _hausbesuch,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) => setState(() => _hausbesuch = v),
                title: Row(
                  children: [
                    const Icon(Icons.home_outlined,
                        size: 20, color: AppTheme.slate700),
                    const SizedBox(width: 8),
                    Text(isDe ? 'Hausbesuch' : 'Home visit',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
                subtitle: Text(
                  isDe
                      ? 'Behandlung beim Patienten zu Hause'
                      : 'Treatment at the patient\'s home',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Therapeut ──
            _SectionHeader(title: isDe ? 'Therapeut' : 'Therapist'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _therapeutId,
              decoration: InputDecoration(
                labelText: isDe
                    ? 'Therapeut zuweisen (optional)'
                    : 'Assign therapist (optional)',
                prefixIcon: const Icon(Icons.psychology_outlined),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(isDe ? '— Nicht zugewiesen —' : '— Unassigned —'),
                ),
                ..._therapeuten.map((t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.name),
                    )),
              ],
              onChanged: (v) => setState(() => _therapeutId = v),
            ),
            if (_therapeuten.isEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isDe
                      ? 'Keine Therapeuten angelegt — bitte unter Einstellungen → Therapeuten hinzufügen.'
                      : 'No therapists set up — please add them in Settings → Therapists.',
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate500,
                      ),
                ),
              ),
            ],
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
