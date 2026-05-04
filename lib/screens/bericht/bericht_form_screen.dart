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
  bool _saving = false;
  bool _uploadingAnhang = false;
  late final String _berichtId;

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

    _kategorie = b?.kategorie ?? defaultKategorie;
    _patient = widget.args.patient;
    _anhaenge = b?.anhaenge.toList() ?? [];
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

            // ── Patient-Auswahl ──
            if (_patient != null)
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
                    TextButton.icon(
                      onPressed: _pickPatient,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Ändern'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    if (!_isEditing)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _patient = null),
                        tooltip: 'Patient entfernen',
                      ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickPatient,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Patient zuweisen (optional)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            const SizedBox(height: 16),

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

            // ── Inhalt (Rich Text Editor) ──
            Text(
              'Inhalt *',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.slate700,
                  ),
            ),
            const SizedBox(height: 6),
            BerichtRichEditor(
              key: _editorReloadKey,
              initialDelta: _initialInhalt,
              onChanged: (delta, plain) {
                _aktuelleDeltaJson = delta;
                _aktuellerPlaintext = plain;
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Tipp: H1/H2 für Überschriften · ☐ für Checkbox-Listen · ★ für Aufzählung',
              style: TextStyle(fontSize: 11, color: AppTheme.slate500),
            ),
            const SizedBox(height: 20),

            // ── Anhaenge ──
            Row(
              children: [
                Text(
                  'Anhänge',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${_anhaenge.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _uploadingAnhang ? null : _addAnhang,
                  icon: _uploadingAnhang
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file, size: 18),
                  label: const Text('Datei anhängen'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_anhaenge.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  border: Border.all(color: AppTheme.slate200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_outlined,
                        size: 16, color: AppTheme.slate400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keine Anhänge — PDF, Bilder (JPG/PNG) bis 25 MB möglich',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ..._anhaenge.map((a) => _AnhangTile(
                  anhang: a,
                  onTap: () => _openAnhang(a),
                  onRemove: () => _removeAnhang(a),
                )),
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
