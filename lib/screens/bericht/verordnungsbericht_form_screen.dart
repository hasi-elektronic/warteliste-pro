import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/bericht.dart';
import '../../models/patient.dart';
import '../../models/verordnungsbericht_data.dart';
import '../../providers/patienten_provider.dart';
import '../../providers/standort_provider.dart';
import '../../services/verordnungsbericht_pdf_service.dart';
import '../../utils/theme.dart';
import '../../widgets/app_header.dart';

/// Strukturiertes Formular für den Verordnungs-Bericht (GKV Anhang A).
///
/// Der User füllt strukturierte Felder aus; beim Generieren wird das
/// Original-PDF (mit Briefkopf je nach Standort) als Hintergrund verwendet
/// und die Daten an die richtigen Stellen overlay'ed — Ergebnis sieht aus
/// wie das Original mit ausgefüllten Feldern.
class VerordnungsberichtFormScreen extends ConsumerStatefulWidget {
  /// Optional: Patient, dessen Daten vorausgefüllt werden
  final Patient? patient;

  /// Optional: vorhandenes Datenobjekt zum Bearbeiten (nur Daten)
  final VerordnungsberichtData? initial;

  /// Optional: Existierender Bericht zum Bearbeiten (Firestore-Sync)
  final Bericht? berichtToEdit;

  const VerordnungsberichtFormScreen({
    super.key,
    this.patient,
    this.initial,
    this.berichtToEdit,
  });

  @override
  ConsumerState<VerordnungsberichtFormScreen> createState() =>
      _VerordnungsberichtFormScreenState();
}

class _VerordnungsberichtFormScreenState
    extends ConsumerState<VerordnungsberichtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _vornameCtrl;
  late final TextEditingController _diagnosegruppeCtrl;
  late final TextEditingController _therapeutischeDiagnoseCtrl;
  late final TextEditingController _wiedervorstellungCtrl;
  late final TextEditingController _andereTherapieCtrl;
  late final TextEditingController _einzelMinCtrl;
  late final TextEditingController _gruppeMinCtrl;
  late final TextEditingController _frequenzCtrl;
  late final TextEditingController _zusammenfassungCtrl;

  DateTime? _geburtsdatum;
  DateTime? _verordnungsdatum;
  DateTime? _datum;

  /// Wenn ein Patient zugeordnet ist, sind Name/Vorname/Geburtsdatum
  /// vorausgefuellt. Manuelle Aenderungen bleiben erhalten.
  Patient? _zugeordnerPatient;

  bool _empFortfuehrung = false;
  bool _empTherapiepause = false;
  bool _empBeendigung = false;
  bool _empWiedervorstellung = false;
  bool _empAndereTherapie = false;
  bool _empEinzeltherapie = false;
  bool _empGruppentherapie = false;
  bool _empDoppelbehandlung = false;
  bool _empFrequenz = false;
  bool _empHausbesuch = false;

  bool _generating = false;
  bool _saving = false;

  bool get _isEditing => widget.berichtToEdit != null;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    // Falls ein Firestore-Bericht zum Bearbeiten uebergeben wurde,
    // dessen JSON-Inhalt zu strukturierten Daten parsen.
    final i = widget.initial ??
        (widget.berichtToEdit != null
            ? VerordnungsberichtData.fromJsonString(
                widget.berichtToEdit!.inhalt)
            : null);
    _nameCtrl = TextEditingController(text: i?.name ?? p?.name ?? '');
    _vornameCtrl = TextEditingController(text: i?.vorname ?? p?.vorname ?? '');
    _geburtsdatum = i?.geburtsdatum ?? p?.geburtsdatum;
    _verordnungsdatum = i?.verordnungsdatum;
    _diagnosegruppeCtrl =
        TextEditingController(text: i?.diagnosegruppe ?? '');
    _therapeutischeDiagnoseCtrl = TextEditingController(
        text: i?.therapeutischeDiagnose ?? p?.stoerungsbild ?? '');
    _wiedervorstellungCtrl =
        TextEditingController(text: i?.empWiedervorstellungText ?? '');
    _andereTherapieCtrl =
        TextEditingController(text: i?.empAndereTherapieText ?? '');
    _einzelMinCtrl =
        TextEditingController(text: i?.empEinzeltherapieMinuten ?? '');
    _gruppeMinCtrl =
        TextEditingController(text: i?.empGruppentherapieMinuten ?? '');
    _frequenzCtrl = TextEditingController(text: i?.empFrequenzText ?? '');
    _zusammenfassungCtrl =
        TextEditingController(text: i?.zusammenfassung ?? '');
    _datum = i?.datum ?? DateTime.now();

    _empFortfuehrung = i?.empFortfuehrung ?? false;
    _empTherapiepause = i?.empTherapiepause ?? false;
    _empBeendigung = i?.empBeendigung ?? false;
    _empWiedervorstellung = i?.empWiedervorstellung ?? false;
    _empAndereTherapie = i?.empAndereTherapie ?? false;
    _empEinzeltherapie = i?.empEinzeltherapie ?? false;
    _empGruppentherapie = i?.empGruppentherapie ?? false;
    _empDoppelbehandlung = i?.empDoppelbehandlung ?? false;
    _empFrequenz = i?.empFrequenz ?? false;
    _empHausbesuch = i?.empHausbesuch ?? p?.hausbesuch ?? false;

    _zugeordnerPatient = p;
  }

  Future<void> _pickPatient() async {
    // Patientenliste laden (warten falls Provider noch laedt)
    var asyncPatienten = ref.read(patientenProvider);
    final start = DateTime.now();
    while (asyncPatienten.value == null &&
        DateTime.now().difference(start).inSeconds < 3) {
      await Future.delayed(const Duration(milliseconds: 100));
      asyncPatienten = ref.read(patientenProvider);
    }
    final patienten = asyncPatienten.value ?? const [];
    if (!mounted) return;
    if (patienten.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Keine Patienten in dieser Praxis gefunden')),
      );
      return;
    }
    final selected = await showModalBottomSheet<Patient>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VbPatientPickerSheet(patienten: patienten),
    );
    if (selected != null && mounted) {
      _applyPatient(selected, showFeedback: true);
    }
  }

  /// Patient-Daten in die Form-Felder übertragen.
  void _applyPatient(Patient p, {bool showFeedback = false}) {
    setState(() {
      _zugeordnerPatient = p;
      _nameCtrl.text = p.name;
      _vornameCtrl.text = p.vorname;
      _geburtsdatum = p.geburtsdatum;
      if (p.stoerungsbild.isNotEmpty &&
          _therapeutischeDiagnoseCtrl.text.isEmpty) {
        _therapeutischeDiagnoseCtrl.text = p.stoerungsbild;
      }
      _empHausbesuch = p.hausbesuch || _empHausbesuch;
    });
    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Daten von "${p.vollstaendigerName}" übernommen'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vornameCtrl.dispose();
    _diagnosegruppeCtrl.dispose();
    _therapeutischeDiagnoseCtrl.dispose();
    _wiedervorstellungCtrl.dispose();
    _andereTherapieCtrl.dispose();
    _einzelMinCtrl.dispose();
    _gruppeMinCtrl.dispose();
    _frequenzCtrl.dispose();
    _zusammenfassungCtrl.dispose();
    super.dispose();
  }

  String _resolveStandortKey() {
    final praxis = ref.read(aktivesPraxisProvider);
    final name = praxis?.name.toLowerCase() ?? '';
    if (!name.contains('menauer')) return 'blanko';
    if (name.contains('ditzingen')) return 'ditzingen';
    if (name.contains('vaihingen')) return 'vaihingen';
    return 'weil';
  }

  VerordnungsberichtData _collect() {
    return VerordnungsberichtData(
      name: _nameCtrl.text.trim(),
      vorname: _vornameCtrl.text.trim(),
      geburtsdatum: _geburtsdatum,
      verordnungsdatum: _verordnungsdatum,
      diagnosegruppe: _diagnosegruppeCtrl.text.trim(),
      therapeutischeDiagnose: _therapeutischeDiagnoseCtrl.text.trim(),
      empFortfuehrung: _empFortfuehrung,
      empTherapiepause: _empTherapiepause,
      empBeendigung: _empBeendigung,
      empWiedervorstellung: _empWiedervorstellung,
      empWiedervorstellungText: _wiedervorstellungCtrl.text.trim(),
      empAndereTherapie: _empAndereTherapie,
      empAndereTherapieText: _andereTherapieCtrl.text.trim(),
      empEinzeltherapie: _empEinzeltherapie,
      empEinzeltherapieMinuten: _einzelMinCtrl.text.trim(),
      empGruppentherapie: _empGruppentherapie,
      empGruppentherapieMinuten: _gruppeMinCtrl.text.trim(),
      empDoppelbehandlung: _empDoppelbehandlung,
      empFrequenz: _empFrequenz,
      empFrequenzText: _frequenzCtrl.text.trim(),
      empHausbesuch: _empHausbesuch,
      zusammenfassung: _zusammenfassungCtrl.text.trim(),
      datum: _datum,
      standortKey: _resolveStandortKey(),
    );
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

      final data = _collect();
      final inhalt = data.toJsonString();
      final patientName = '${data.vorname} ${data.name}'.trim();
      final fmt = DateFormat('dd.MM.yyyy');
      final datumStr = fmt.format(data.datum ?? DateTime.now());
      final inhaltText =
          'Verordnungs-Bericht — $patientName — $datumStr\n'
          'Diagnose: ${data.therapeutischeDiagnose}\n'
          '${data.zusammenfassung}';
      final titel = patientName.isNotEmpty
          ? 'Verordnungs-Bericht — $patientName'
          : 'Verordnungs-Bericht';

      if (_isEditing) {
        final updated = widget.berichtToEdit!.copyWith(
          titel: titel,
          inhalt: inhalt,
          inhaltText: inhaltText,
          kategorie: BerichtKategorie.verordnungsbericht,
          aktualisiertAm: DateTime.now(),
        );
        await svc.updateBericht(updated);
      } else {
        final neu = Bericht(
          id: '',
          praxisId: praxisId,
          patientId: widget.patient?.id,
          patientName:
              widget.patient?.vollstaendigerName ?? patientName,
          authorUid: user.uid,
          authorEmail: user.email ?? '',
          authorName: user.displayName,
          erstelltAm: DateTime.now(),
          kategorie: BerichtKategorie.verordnungsbericht,
          titel: titel,
          inhalt: inhalt,
          inhaltText: inhaltText,
        );
        await svc.addBericht(neu);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verordnungs-Bericht gespeichert')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speichern fehlgeschlagen: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generieren({required bool share}) async {
    setState(() => _generating = true);
    try {
      final data = _collect();
      final praxis = ref.read(aktivesPraxisProvider);
      if (share) {
        await VerordnungsberichtPdfService.teilen(data, praxis: praxis);
      } else {
        await VerordnungsberichtPdfService.drucken(data, praxis: praxis);
      }
    } catch (e, st) {
      if (mounted) {
        // ignore: avoid_print
        print('PDF Error: $e\n$st');
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline,
                color: AppTheme.errorColor, size: 36),
            title: const Text('PDF-Generierung fehlgeschlagen'),
            content: SingleChildScrollView(
              child: SelectableText('$e',
                  style: const TextStyle(fontSize: 12)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Schließen'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      cancelText: 'Abbrechen',
      confirmText: 'Übernehmen',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pre-warm: Patientenliste im Hintergrund laden, damit der Picker
    // beim ersten Klick sofort verfügbar ist.
    ref.watch(patientenProvider);

    return Scaffold(
      backgroundColor: AppTheme.slate100,
      appBar: AppHeader(
        title: _isEditing
            ? 'Verordnungs-Bericht bearbeiten'
            : 'Verordnungs-Bericht',
        icon: Icons.assignment_outlined,
        showBackButton: true,
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                // ── 0) Patient-Verknüpfung ─────────────────────
                _SectionCard(
                  icon: Icons.link,
                  titel: 'Patient verknüpfen',
                  subtitle:
                      'Optional — füllt Name, Vorname & Geburtsdatum vor',
                  child: _zugeordnerPatient == null
                      ? _PickPatientButton(onTap: _pickPatient)
                      : _PatientPill(
                          patient: _zugeordnerPatient!,
                          onChange: _pickPatient,
                          onClear: () =>
                              setState(() => _zugeordnerPatient = null),
                        ),
                ),
                const SizedBox(height: 12),

                // ── 1) Personalien ──────────────────────────────
                _SectionCard(
                  icon: Icons.person_outline,
                  titel: 'Personalien der/des Versicherten',
                  subtitle:
                      'Pflichtfelder — bei verknüpftem Patient automatisch gefüllt, manuell anpassbar',
                  child: LayoutBuilder(
                    builder: (ctx, bc) {
                      final wide = bc.maxWidth > 480;
                      final nameField = TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Pflichtfeld'
                                : null,
                      );
                      final vornameField = TextFormField(
                        controller: _vornameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Vorname *',
                          prefixIcon: Icon(Icons.person_outline, size: 18),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Pflichtfeld'
                                : null,
                      );
                      return Column(
                        children: [
                          if (wide)
                            Row(children: [
                              Expanded(child: nameField),
                              const SizedBox(width: 10),
                              Expanded(child: vornameField),
                            ])
                          else ...[
                            nameField,
                            const SizedBox(height: 10),
                            vornameField,
                          ],
                          const SizedBox(height: 12),
                          _DateTile(
                            label: 'Geburtsdatum',
                            value: _geburtsdatum,
                            onTap: () async {
                              final picked = await _pickDate(_geburtsdatum);
                              if (picked != null) {
                                setState(() => _geburtsdatum = picked);
                              }
                            },
                            onClear: _geburtsdatum != null
                                ? () =>
                                    setState(() => _geburtsdatum = null)
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ── 2) Verordnung ───────────────────────────────
                _SectionCard(
                  icon: Icons.medical_information_outlined,
                  titel: 'Verordnung',
                  child: Column(
                    children: [
                      _DateTile(
                        label: 'Verordnungsdatum',
                        value: _verordnungsdatum,
                        onTap: () async {
                          final picked = await _pickDate(_verordnungsdatum);
                          if (picked != null) {
                            setState(() => _verordnungsdatum = picked);
                          }
                        },
                        onClear: _verordnungsdatum != null
                            ? () =>
                                setState(() => _verordnungsdatum = null)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _diagnosegruppeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosegruppe',
                          hintText: 'z.B. SP1',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _therapeutischeDiagnoseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Therapeutische Diagnose',
                          alignLabelWithHint: true,
                        ),
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── 3) Empfehlungen ─────────────────────────────
                _SectionCard(
                  icon: Icons.checklist_rtl,
                  titel: 'Empfehlungen',
                  subtitle: 'Auswahl per Klick — mehrere möglich',
                  child: Column(
                    children: [
                      _CheckRow(
                        label: 'Fortführung der Therapie',
                        value: _empFortfuehrung,
                        onChanged: (v) => setState(() => _empFortfuehrung = v),
                      ),
                      _CheckRow(
                        label: 'Therapiepause',
                        value: _empTherapiepause,
                        onChanged: (v) =>
                            setState(() => _empTherapiepause = v),
                      ),
                      _CheckRow(
                        label: 'Beendigung der Therapie',
                        value: _empBeendigung,
                        onChanged: (v) => setState(() => _empBeendigung = v),
                      ),
                      _CheckRow(
                        label: 'Wiedervorstellung',
                        value: _empWiedervorstellung,
                        onChanged: (v) =>
                            setState(() => _empWiedervorstellung = v),
                        trailing: _empWiedervorstellung
                            ? SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: _wiedervorstellungCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'z.B. in 3 Monaten',
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )
                            : null,
                      ),
                      _CheckRow(
                        label: 'Andere Therapie',
                        value: _empAndereTherapie,
                        onChanged: (v) =>
                            setState(() => _empAndereTherapie = v),
                        trailing: _empAndereTherapie
                            ? SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: _andereTherapieCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Bezeichnung',
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )
                            : null,
                      ),
                      const Divider(height: 24),
                      _CheckRow(
                        label: 'Einzeltherapie',
                        value: _empEinzeltherapie,
                        onChanged: (v) =>
                            setState(() => _empEinzeltherapie = v),
                        trailing: _empEinzeltherapie
                            ? SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: _einzelMinCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Min.',
                                    suffixText: 'min',
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )
                            : null,
                      ),
                      _CheckRow(
                        label: 'Gruppentherapie',
                        value: _empGruppentherapie,
                        onChanged: (v) =>
                            setState(() => _empGruppentherapie = v),
                        trailing: _empGruppentherapie
                            ? SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: _gruppeMinCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Min.',
                                    suffixText: 'min',
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )
                            : null,
                      ),
                      _CheckRow(
                        label: 'Doppelbehandlung',
                        value: _empDoppelbehandlung,
                        onChanged: (v) =>
                            setState(() => _empDoppelbehandlung = v),
                      ),
                      _CheckRow(
                        label: 'Frequenz',
                        value: _empFrequenz,
                        onChanged: (v) => setState(() => _empFrequenz = v),
                        trailing: _empFrequenz
                            ? SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: _frequenzCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Anz./Wo',
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )
                            : null,
                      ),
                      _CheckRow(
                        label: 'Hausbesuch',
                        value: _empHausbesuch,
                        onChanged: (v) => setState(() => _empHausbesuch = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── 4) Zusammenfassung Therapieverlauf ──────────
                _SectionCard(
                  icon: Icons.notes_outlined,
                  titel: 'Zusammenfassung Therapieverlauf',
                  subtitle: 'ggf. Begründung zur Empfehlung',
                  child: TextFormField(
                    controller: _zusammenfassungCtrl,
                    decoration: const InputDecoration(
                      hintText:
                          'Therapieverlauf, Beobachtungen, Begründung …',
                      alignLabelWithHint: true,
                    ),
                    minLines: 6,
                    maxLines: 14,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: 12),

                // ── 5) Datum ────────────────────────────────────
                _SectionCard(
                  icon: Icons.event_outlined,
                  titel: 'Datum',
                  subtitle: 'Datum der Berichtserstellung',
                  child: _DateTile(
                    label: 'Datum',
                    value: _datum,
                    onTap: () async {
                      final picked = await _pickDate(_datum);
                      if (picked != null) {
                        setState(() => _datum = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),

            // ── Sticky Action Bar ─────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                      top: BorderSide(color: AppTheme.slate200)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.slate900.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: (_saving || _generating)
                              ? null
                              : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(
                              _saving ? 'Speichert …' : 'Speichern'),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _generating
                                  ? null
                                  : () => _generieren(share: true),
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('PDF laden'),
                            ),
                            FilledButton.icon(
                              onPressed: _generating
                                  ? null
                                  : () => _generieren(share: false),
                              icon: _generating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.print_outlined,
                                      size: 18),
                              label: Text(_generating
                                  ? 'Generiert …'
                                  : 'PDF erstellen'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Section Card
// ════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String titel;
  final String? subtitle;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.titel,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.slate900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.slate500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CheckRow + DateTile
// ════════════════════════════════════════════════════════════════

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate800,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasValue ? AppTheme.primarySurface : AppTheme.slate50,
          border: Border.all(
            color: hasValue
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : AppTheme.slate300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: hasValue
                    ? AppTheme.primaryColor
                    : AppTheme.slate600),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.slate600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hasValue
                        ? DateFormat('dd.MM.yyyy').format(value!)
                        : '—',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: hasValue
                          ? AppTheme.slate900
                          : AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                onPressed: onClear,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickPatientButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PickPatientButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.slate300),
        ),
        child: Row(
          children: const [
            Icon(Icons.person_search,
                color: AppTheme.slate600, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Patient aus Liste auswählen',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppTheme.slate400, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PatientPill extends StatelessWidget {
  final Patient patient;
  final VoidCallback onChange;
  final VoidCallback onClear;
  const _PatientPill({
    required this.patient,
    required this.onChange,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryColor,
            child: Icon(Icons.person, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              patient.vollstaendigerName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz, size: 14),
            label: const Text('Ändern'),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onClear,
            tooltip: 'Verknüpfung entfernen',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(28, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-Sheet zum Auswählen eines Patienten mit Suche.
class _VbPatientPickerSheet extends StatefulWidget {
  final List<Patient> patienten;
  const _VbPatientPickerSheet({required this.patienten});

  @override
  State<_VbPatientPickerSheet> createState() =>
      _VbPatientPickerSheetState();
}

class _VbPatientPickerSheetState extends State<_VbPatientPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().trim();
    final liste = widget.patienten.where((p) {
      if (q.isEmpty) return true;
      return p.vollstaendigerName.toLowerCase().contains(q) ||
          p.stoerungsbild.toLowerCase().contains(q) ||
          p.telefon.contains(q);
    }).toList()
      ..sort((a, b) => a.vollstaendigerName
          .toLowerCase()
          .compareTo(b.vollstaendigerName.toLowerCase()));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => SafeArea(
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.person_search,
                      color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Patient auswählen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Name, Telefon, Störungsbild …',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: liste.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Keine Patienten gefunden'),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: liste.length,
                      itemBuilder: (_, i) {
                        final p = liste[i];
                        final initials = (p.vorname.isNotEmpty
                                ? p.vorname[0].toUpperCase()
                                : '') +
                            (p.name.isNotEmpty
                                ? p.name[0].toUpperCase()
                                : '');
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor
                                .withValues(alpha: 0.12),
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            p.vollstaendigerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (p.stoerungsbild.isNotEmpty) p.stoerungsbild,
                              p.status.label,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.slate400),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
