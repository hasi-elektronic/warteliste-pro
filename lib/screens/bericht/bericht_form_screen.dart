import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/bericht.dart';
import '../../models/bericht_anhang.dart';
import '../../models/patient.dart';
import '../../providers/patienten_provider.dart';
import '../../providers/standort_provider.dart';
import '../../services/bericht_pdf_service.dart';
import '../../services/bericht_upload_service.dart';
import '../../services/praxis_briefpapier.dart';
import '../../utils/theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bericht_rich_editor.dart';

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
  Key _editorReloadKey = UniqueKey();
  String _initialInhalt = '';
  String _aktuelleDeltaJson = '';
  String _aktuellerPlaintext = '';

  late BerichtKategorie _kategorie;
  Patient? _patient;
  late List<BerichtAnhang> _anhaenge;
  DateTime? _briefDatum;
  bool _saving = false;
  bool _uploadingAnhang = false;
  late final String _berichtId;

  bool get _isEditing => widget.args.bericht != null;

  @override
  void initState() {
    super.initState();
    final b = widget.args.bericht;
    _titelCtrl = TextEditingController(text: b?.titel ?? '');

    // Default immer Allgemein — User soll bewusst eine Vorlage waehlen.
    final defaultKategorie =
        widget.args.kategorie ?? BerichtKategorie.allgemein;

    _kategorie = b?.kategorie ?? defaultKategorie;
    _patient = widget.args.patient;
    _anhaenge = b?.anhaenge.toList() ?? [];
    _briefDatum = b?.briefDatum;
    _berichtId = (b?.id.isNotEmpty ?? false) ? b!.id : const Uuid().v4();

    _initialInhalt = b?.inhalt ?? defaultKategorie.vorlage;
    _aktuelleDeltaJson = _initialInhalt;
    _aktuellerPlaintext = b?.inhaltText ?? defaultKategorie.vorlage;
  }

  @override
  void dispose() {
    _titelCtrl.dispose();
    super.dispose();
  }

  Future<void> _printPdf() async {
    if (widget.args.bericht == null) return;
    try {
      final praxis = ref.read(aktivesPraxisProvider);
      final briefpapier = await PraxisBriefpapierService.forPraxis(praxis);
      final aktuell = widget.args.bericht!.copyWith(
        titel: _titelCtrl.text.trim(),
        inhalt: _aktuelleDeltaJson,
        inhaltText: _aktuellerPlaintext,
        kategorie: _kategorie,
        anhaenge: _anhaenge,
        briefDatum: _briefDatum,
        clearBriefDatum: _briefDatum == null &&
            widget.args.bericht!.briefDatum != null,
      );
      await BerichtPdfService.druckeBericht(
        bericht: aktuell,
        briefpapier: briefpapier,
      );
    } catch (e, st) {
      if (mounted) {
        // ignore: avoid_print
        print('PDF Error: $e\n$st');
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline,
                color: AppTheme.errorColor, size: 36),
            title: const Text('PDF-Export fehlgeschlagen'),
            content: SingleChildScrollView(
              child: SelectableText(
                '$e',
                style: const TextStyle(fontSize: 12),
              ),
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
    }
  }

  void _applyVorlage(BerichtKategorie k) {
    setState(() {
      _kategorie = k;
      final aktuell = _aktuellerPlaintext.trim();
      final alteVorlagen =
          BerichtKategorie.values.map((e) => e.vorlage.trim()).toSet();
      if (aktuell.isEmpty || alteVorlagen.contains(aktuell)) {
        _initialInhalt = k.vorlage;
        _aktuelleDeltaJson = k.vorlage;
        _aktuellerPlaintext = k.vorlage;
        _editorReloadKey = UniqueKey();
      }
    });
  }

  Future<void> _addAnhang() async {
    final praxisId = ref.read(praxisIdProvider);
    if (praxisId == null) return;
    setState(() => _uploadingAnhang = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final bytes = picked.bytes;
      if (bytes == null) {
        throw Exception('Datei konnte nicht gelesen werden');
      }
      if (bytes.lengthInBytes > 25 * 1024 * 1024) {
        throw Exception('Datei zu groß (max. 25 MB)');
      }
      final ext = (picked.extension ?? '').toLowerCase();
      String contentType;
      switch (ext) {
        case 'pdf':
          contentType = 'application/pdf';
          break;
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        case 'heic':
          contentType = 'image/heic';
          break;
        default:
          throw Exception('Dateityp nicht unterstützt');
      }

      final upload = await BerichtUploadService.uploadAnhang(
        bytes: Uint8List.fromList(bytes),
        fileName: picked.name,
        contentType: contentType,
        praxisId: praxisId,
        berichtId: _berichtId,
      );

      setState(() {
        _anhaenge.add(BerichtAnhang(
          id: const Uuid().v4(),
          name: picked.name,
          url: upload.url,
          contentType: contentType,
          groesseBytes: bytes.lengthInBytes,
          hochgeladenAm: DateTime.now(),
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anhang-Fehler: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAnhang = false);
    }
  }

  Future<void> _removeAnhang(BerichtAnhang a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anhang entfernen?'),
        content: Text('"${a.name}" wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor),
              child: const Text('Entfernen')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _anhaenge.removeWhere((x) => x.id == a.id));
    BerichtUploadService.deleteAnhang(a.url);
  }

  Future<void> _pickBriefDatum() async {
    final initial = _briefDatum ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Datum für den Brief',
      cancelText: 'Abbrechen',
      confirmText: 'Übernehmen',
    );
    if (picked != null) {
      setState(() => _briefDatum = picked);
    }
  }

  Future<void> _pickPatient() async {
    final asyncPatienten = ref.read(patientenProvider);
    final patienten = asyncPatienten.value ?? const [];
    if (patienten.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Patienten in dieser Praxis')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Patient>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PatientPickerSheet(patienten: patienten),
    );
    if (selected != null) {
      setState(() => _patient = selected);
    }
  }

  Future<void> _openAnhang(BerichtAnhang a) async {
    try {
      final signed = await BerichtUploadService.getSignedUrl(a.url);
      final uri = Uri.parse(signed);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Datei konnte nicht geöffnet werden: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_aktuellerPlaintext.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Inhalt eingeben')),
      );
      return;
    }
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
          inhalt: _aktuelleDeltaJson,
          inhaltText: _aktuellerPlaintext,
          kategorie: _kategorie,
          aktualisiertAm: DateTime.now(),
          anhaenge: _anhaenge,
          briefDatum: _briefDatum,
          clearBriefDatum: _briefDatum == null &&
              widget.args.bericht!.briefDatum != null,
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
          inhalt: _aktuelleDeltaJson,
          inhaltText: _aktuellerPlaintext,
          anhaenge: _anhaenge,
          briefDatum: _briefDatum,
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
      backgroundColor: AppTheme.slate100,
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
        child: Stack(
          children: [
            // Hauptinhalt
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // ── 1) Vorlage Auswahl ──
                _SectionCard(
                  icon: Icons.dashboard_customize_outlined,
                  titel: 'Vorlage',
                  subtitle:
                      'Wählen Sie eine Vorlage — der Inhalt wird voreingestellt',
                  child: _VorlageRow(
                    aktiv: _kategorie,
                    onSelect: _applyVorlage,
                  ),
                ),
                const SizedBox(height: 12),

                // ── 2) Patient / Empfänger + Datum (zwei Spalten auf Wide) ──
                LayoutBuilder(
                  builder: (ctx, bc) {
                    final twoCol = bc.maxWidth > 700;
                    final patientCard = _SectionCard(
                      icon: _kategorie == BerichtKategorie.brief
                          ? Icons.mail_outline
                          : Icons.person_outline,
                      titel: _kategorie == BerichtKategorie.brief
                          ? 'Empfänger'
                          : 'Patient',
                      subtitle: _kategorie == BerichtKategorie.brief
                          ? 'Optional: Empfänger des Schreibens'
                          : 'Optional: Bezug auf einen Patienten',
                      child: _patient != null
                          ? _PatientPill(
                              name: _patient!.vollstaendigerName,
                              onChange: _pickPatient,
                              onRemove: _isEditing
                                  ? null
                                  : () => setState(() => _patient = null),
                            )
                          : _PatientEmptyButton(onTap: _pickPatient),
                    );
                    final datumCard = _SectionCard(
                      icon: Icons.event_outlined,
                      titel: 'Datum',
                      subtitle:
                          'Erscheint im Brief — leer = heute',
                      child: _DatumPicker(
                        date: _briefDatum,
                        onPick: _pickBriefDatum,
                        onClear: _briefDatum != null
                            ? () => setState(() => _briefDatum = null)
                            : null,
                      ),
                    );
                    if (twoCol) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: patientCard),
                          const SizedBox(width: 12),
                          SizedBox(width: 280, child: datumCard),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        patientCard,
                        const SizedBox(height: 12),
                        datumCard,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ── 3) Inhalt — auf "A4-Kagit" ──
                _SectionCard(
                  icon: Icons.article_outlined,
                  titel: 'Inhalt',
                  subtitle:
                      _kategorie == BerichtKategorie.brief
                          ? 'Betrifft, Anrede, Inhalt, Schluss'
                          : 'Titel + formattierter Bericht',
                  padded: false,
                  child: _PaperEditor(
                    titelCtrl: _titelCtrl,
                    editorReloadKey: _editorReloadKey,
                    initialInhalt: _initialInhalt,
                    onEditorChanged: (delta, plain) {
                      _aktuelleDeltaJson = delta;
                      _aktuellerPlaintext = plain;
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ── 4) Anhaenge ──
                _SectionCard(
                  icon: Icons.attach_file,
                  titel: 'Anhänge',
                  subtitle:
                      'PDF, Bilder (JPG/PNG/WebP/HEIC) — bis 25 MB pro Datei',
                  trailing: TextButton.icon(
                    onPressed: _uploadingAnhang ? null : _addAnhang,
                    icon: _uploadingAnhang
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: Text(_uploadingAnhang ? 'Lädt …' : 'Datei hinzufügen'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: _anhaenge.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_upload_outlined,
                                  size: 18, color: AppTheme.slate400),
                              const SizedBox(width: 8),
                              Text(
                                'Noch keine Anhänge',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.slate500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: _anhaenge
                              .map((a) => _AnhangTile(
                                    anhang: a,
                                    onTap: () => _openAnhang(a),
                                    onRemove: () => _removeAnhang(a),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 12),
              ],
            ),

            // ── Sticky Save Bar ──
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _StickySaveBar(
                saving: _saving,
                onSave: _save,
                onPdf: _isEditing ? _printPdf : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Premium Section Card
// ════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String titel;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool padded;

  const _SectionCard({
    required this.icon,
    required this.titel,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.slate900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header-Zeile
          Padding(
            padding: EdgeInsets.fromLTRB(
                padded ? 18 : 18, 14, padded ? 14 : 14, padded ? 6 : 14),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
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
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (padded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: child,
            )
          else
            child,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Vorlage Row — moderner als Wrap-Chips
// ════════════════════════════════════════════════════════════════

class _VorlageRow extends StatelessWidget {
  final BerichtKategorie aktiv;
  final ValueChanged<BerichtKategorie> onSelect;
  const _VorlageRow({required this.aktiv, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: BerichtKategorie.values
            .map((k) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _VorlageChipModern(
                    kategorie: k,
                    selected: aktiv == k,
                    onTap: () => onSelect(k),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _VorlageChipModern extends StatefulWidget {
  final BerichtKategorie kategorie;
  final bool selected;
  final VoidCallback onTap;
  const _VorlageChipModern({
    required this.kategorie,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_VorlageChipModern> createState() => _VorlageChipModernState();
}

class _VorlageChipModernState extends State<_VorlageChipModern> {
  bool _hover = false;

  IconData _iconFor(BerichtKategorie k) {
    switch (k) {
      case BerichtKategorie.verordnungsbericht:
        return Icons.assignment_outlined;
      case BerichtKategorie.brief:
        return Icons.mail_outline;
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
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : (_hover ? AppTheme.primarySurface : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : (_hover
                    ? AppTheme.primaryColor.withValues(alpha: 0.4)
                    : AppTheme.slate300),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(widget.kategorie),
                      size: 16,
                      color: selected ? Colors.white : AppTheme.slate700),
                  const SizedBox(width: 8),
                  Text(
                    widget.kategorie.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: selected ? Colors.white : AppTheme.slate800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Patient Empty + Pill
// ════════════════════════════════════════════════════════════════

class _PatientEmptyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PatientEmptyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.slate300, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add_alt_1_outlined,
                color: AppTheme.slate600, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Person zuweisen',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.slate400, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PatientPill extends StatelessWidget {
  final String name;
  final VoidCallback onChange;
  final VoidCallback? onRemove;
  const _PatientPill(
      {required this.name, required this.onChange, this.onRemove});

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
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.person, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz, size: 14),
            label: const Text('Ändern'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onRemove,
              tooltip: 'Entfernen',
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

// ════════════════════════════════════════════════════════════════
// Paper Editor — A4-aehnlicher weisser Bereich
// ════════════════════════════════════════════════════════════════

class _PaperEditor extends StatelessWidget {
  final TextEditingController titelCtrl;
  final Key editorReloadKey;
  final String initialInhalt;
  final void Function(String, String) onEditorChanged;

  const _PaperEditor({
    required this.titelCtrl,
    required this.editorReloadKey,
    required this.initialInhalt,
    required this.onEditorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.slate50,
        border: Border(
          top: BorderSide(color: AppTheme.slate200),
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(13),
          bottomRight: Radius.circular(13),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.slate900.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Titel als großer Betreff
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                  child: TextFormField(
                    controller: titelCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Titel / Betreff',
                      hintStyle: TextStyle(
                        color: AppTheme.slate400,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                      letterSpacing: -0.4,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Bitte einen Titel eingeben';
                      }
                      return null;
                    },
                  ),
                ),
                const Divider(height: 1, color: AppTheme.slate200),
                // Editor mit eigener Toolbar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: BerichtRichEditor(
                    key: editorReloadKey,
                    initialDelta: initialInhalt,
                    onChanged: onEditorChanged,
                    minHeight: 480,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Sticky Save Bar
// ════════════════════════════════════════════════════════════════

class _StickySaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback? onPdf;

  const _StickySaveBar({
    required this.saving,
    required this.onSave,
    this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppTheme.slate200)),
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
          child: Row(
            children: [
              if (onPdf != null) ...[
                OutlinedButton.icon(
                  onPressed: onPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF Vorschau'),
                ),
                const SizedBox(width: 10),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(saving ? 'Speichert …' : 'Bericht speichern'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                ),
              ),
            ],
          ),
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
      case BerichtKategorie.verordnungsbericht:
        return Icons.assignment_outlined;
      case BerichtKategorie.brief:
        return Icons.mail_outline;
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

class _AnhangTile extends StatelessWidget {
  final BerichtAnhang anhang;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _AnhangTile({
    required this.anhang,
    required this.onTap,
    required this.onRemove,
  });

  IconData get _icon {
    if (anhang.istPdf) return Icons.picture_as_pdf;
    if (anhang.istBild) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color get _color {
    if (anhang.istPdf) return AppTheme.errorColor;
    if (anhang.istBild) return AppTheme.accentColor;
    return AppTheme.slate600;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.slate300),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_icon, size: 18, color: _color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anhang.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        anhang.dateigroesseLesbar,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppTheme.slate500,
                  tooltip: 'Entfernen',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-Sheet zum Auswaehlen eines Patienten mit Suchfeld.
class _PatientPickerSheet extends StatefulWidget {
  final List<Patient> patienten;
  const _PatientPickerSheet({required this.patienten});

  @override
  State<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<_PatientPickerSheet> {
  String _query = '';
  final _searchCtrl = TextEditingController();

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
            // Drag-Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
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
            // Search
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
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

/// Date picker tile — kompakte Anzeige mit Tap zum Aendern.
class _DatumPicker extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  const _DatumPicker({required this.date, required this.onPick, this.onClear});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, dd.MM.yyyy');
    final hasDate = date != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasDate ? AppTheme.primarySurface : AppTheme.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasDate
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.slate300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: hasDate ? AppTheme.primaryColor : AppTheme.slate600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDate) ...[
                    Text(
                      DateFormat('dd.MM.yyyy').format(date!),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.slate900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      fmt.format(date!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.slate600,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Heute',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.slate700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Zum Auswählen tippen',
                      style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                    ),
                  ],
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClear,
                tooltip: 'Auf Heute zurücksetzen',
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
