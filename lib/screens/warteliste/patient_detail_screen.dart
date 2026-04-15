import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/strings.dart';
import '../../models/dokument.dart';
import '../../models/patient.dart';
import '../../models/patient_note.dart';
import '../../providers/patienten_provider.dart';
import '../../services/dokument_service.dart';
import '../../utils/theme.dart';
import '../../widgets/status_badge.dart';

/// Detail-Ansicht eines einzelnen Patienten.
///
/// Zeigt alle Patientendaten in gruppierten Karten an und bietet
/// Aktionen wie Status aendern, Bearbeiten, Anrufen und Loeschen.
class PatientDetailScreen extends ConsumerWidget {
  final Patient patient;

  const PatientDetailScreen({
    super.key,
    required this.patient,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aktuellen Patienten aus dem Stream lesen (live-Updates).
    final asyncPatienten = ref.watch(patientenProvider);
    final livePatient = asyncPatienten.whenOrNull(
      data: (list) {
        try {
          return list.firstWhere((p) => p.id == patient.id);
        } catch (_) {
          return null;
        }
      },
    ) ?? patient;

    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(livePatient.vollstaendigerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(
                '/patient/bearbeiten',
                arguments: livePatient,
              );
            },
            tooltip: 'Bearbeiten',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero-Bereich ──
            _HeroSection(patient: livePatient),
            const SizedBox(height: 20),

            // ── Kontakt ──
            _SectionCard(
              title: 'Kontakt',
              icon: Icons.phone_outlined,
              children: [
                if (livePatient.telefon.isNotEmpty)
                  _InfoTile(
                    label: 'Telefon',
                    value: livePatient.telefon,
                    trailing: IconButton(
                      icon: const Icon(Icons.phone, size: 20),
                      color: AppTheme.successColor,
                      onPressed: () => _launchPhone(livePatient.telefon),
                      tooltip: 'Anrufen',
                    ),
                  ),
                if (livePatient.adresse.isNotEmpty)
                  _InfoTile(
                    label: 'Adresse',
                    value: livePatient.adresse,
                    trailing: IconButton(
                      icon: const Icon(Icons.map_outlined, size: 20),
                      color: AppTheme.primaryColor,
                      onPressed: () => _launchMaps(livePatient.adresse),
                      tooltip: 'Karte oeffnen',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Medizinisch ──
            _SectionCard(
              title: 'Medizinisch',
              icon: Icons.medical_information_outlined,
              children: [
                _InfoTile(
                  label: 'Stoerungsbild',
                  value: livePatient.stoerungsbild.isNotEmpty
                      ? livePatient.stoerungsbild
                      : '---',
                ),
                _InfoTile(
                  label: 'Arzt',
                  value: livePatient.arzt.isNotEmpty
                      ? livePatient.arzt
                      : '---',
                ),
                _InfoTile(
                  label: 'Versicherung',
                  value: livePatient.versicherung,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Termine ──
            _SectionCard(
              title: 'Termine',
              icon: Icons.calendar_month_outlined,
              children: [
                _InfoTile(
                  label: 'Terminwunsch',
                  value: livePatient.terminWunsch.isNotEmpty
                      ? livePatient.terminWunsch
                      : '---',
                ),
                if (livePatient.geburtsdatum != null)
                  _InfoTile(
                    label: 'Geburtsdatum',
                    value: dateFormat.format(livePatient.geburtsdatum!),
                  ),
                if (livePatient.weitereInfos.isNotEmpty)
                  _InfoTile(
                    label: 'Weitere Infos',
                    value: livePatient.weitereInfos,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Rezept / Verordnung ──
            _RezeptSection(patient: livePatient),
            const SizedBox(height: 12),

            // ── Therapeut ──
            _SectionCard(
              title: 'Therapeut',
              icon: Icons.person_outline,
              children: [
                _InfoTile(
                  label: 'Zugewiesen',
                  value: livePatient.therapeutId != null &&
                          livePatient.therapeutId!.isNotEmpty
                      ? livePatient.therapeutId!
                      : 'Nicht zugewiesen',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Kontakt-Info ──
            if (livePatient.status == PatientStatus.wartend)
              _KontaktInfoCard(patient: livePatient),
            if (livePatient.status == PatientStatus.wartend)
              const SizedBox(height: 12),

            // ── Dokumente ──
            _DokumenteSection(patient: livePatient),
            const SizedBox(height: 12),

            // ── Notizen & Anrufe ──
            _NotizenSection(patient: livePatient),
            const SizedBox(height: 24),

            // ── Aktionen ──
            _ActionButtons(patient: livePatient),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchMaps(String address) async {
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Hero-Bereich
// ════════════════════════════════════════════════════════════════

class _HeroSection extends StatelessWidget {
  final Patient patient;

  const _HeroSection({required this.patient});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                _initials(patient),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              patient.vollstaendigerName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Status-Badge + Prioritaet
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatusBadge(status: patient.status),
                if (patient.prioritaet != PatientPrioritaet.normal) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: patient.prioritaet == PatientPrioritaet.dringend
                          ? AppTheme.errorColor.withValues(alpha: 0.1)
                          : AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            patient.prioritaet == PatientPrioritaet.dringend
                                ? AppTheme.errorColor.withValues(alpha: 0.3)
                                : AppTheme.warningColor
                                    .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          patient.prioritaet == PatientPrioritaet.dringend
                              ? Icons.priority_high
                              : Icons.arrow_upward,
                          size: 14,
                          color: patient.prioritaet ==
                                  PatientPrioritaet.dringend
                              ? AppTheme.errorColor
                              : AppTheme.warningColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          patient.prioritaet.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: patient.prioritaet ==
                                    PatientPrioritaet.dringend
                                ? AppTheme.errorColor
                                : AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Wartezeit + Anmeldedatum
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MetricChip(
                  icon: Icons.access_time,
                  label: '${patient.wartezeitInTagen} Tage',
                  color: _wartezeitColor(patient.wartezeitInTagen),
                ),
                const SizedBox(width: 12),
                _MetricChip(
                  icon: Icons.calendar_today_outlined,
                  label: dateFormat.format(patient.anmeldung),
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(Patient p) {
    final v = p.vorname.isNotEmpty ? p.vorname[0].toUpperCase() : '';
    final n = p.name.isNotEmpty ? p.name[0].toUpperCase() : '';
    return '$v$n';
  }

  Color _wartezeitColor(int tage) {
    if (tage > 180) return AppTheme.errorColor;
    if (tage > 90) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Info-Karten-Sektion
// ════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoTile({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Aktions-Buttons
// ════════════════════════════════════════════════════════════════

class _ActionButtons extends ConsumerWidget {
  final Patient patient;

  const _ActionButtons({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status aendern
        FilledButton.icon(
          onPressed: () => _showStatusDialog(context, ref),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Status aendern'),
        ),
        const SizedBox(height: 8),

        // Bearbeiten
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pushNamed(
              '/patient/bearbeiten',
              arguments: patient,
            );
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Bearbeiten'),
        ),
        const SizedBox(height: 8),

        // Anrufen
        if (patient.telefon.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri(scheme: 'tel', path: patient.telefon);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            icon: const Icon(Icons.phone_outlined),
            label: const Text('Anrufen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.successColor,
              side: const BorderSide(color: AppTheme.successColor),
            ),
          ),
        const SizedBox(height: 8),

        // Loeschen
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Loeschen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: const BorderSide(color: AppTheme.errorColor),
          ),
        ),
      ],
    );
  }

  Future<void> _showStatusDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
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

    if (newStatus != null && newStatus != patient.status) {
      final service = ref.read(firebaseServiceProvider);
      await service.updatePatientStatus(
        patient.praxisId,
        patient.id,
        newStatus,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status geaendert: ${newStatus.label}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
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

    if (confirmed == true) {
      final service = ref.read(firebaseServiceProvider);
      await service.deletePatient(patient.praxisId, patient.id);
      if (context.mounted) {
        Navigator.of(context).pop(); // Zurueck zur Liste
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${patient.vollstaendigerName} geloescht'),
          ),
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Notizen & Anruf-Protokoll Sektion
// ════════════════════════════════════════════════════════════════

class _NotizenSection extends ConsumerWidget {
  final Patient patient;

  const _NotizenSection({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final notizenAsync = ref.watch(notizenProvider(patient.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.notes_outlined, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.notizenTitel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                ),
                _NoteAddButton(
                  icon: Icons.note_add_outlined,
                  tooltip: s.notizHinzufuegen,
                  onPressed: () => _showNoteDialog(context, ref, NoteType.notiz),
                ),
                const SizedBox(width: 4),
                _NoteAddButton(
                  icon: Icons.phone_callback_outlined,
                  tooltip: s.anrufProtokollieren,
                  onPressed: () => _showNoteDialog(context, ref, NoteType.anruf),
                ),
                const SizedBox(width: 4),
                _NoteAddButton(
                  icon: Icons.email_outlined,
                  tooltip: s.emailProtokollieren,
                  onPressed: () => _showNoteDialog(context, ref, NoteType.email),
                ),
              ],
            ),
            const Divider(height: 20),

            notizenAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Fehler: $e',
                    style: TextStyle(color: AppTheme.errorColor)),
              ),
              data: (notizen) {
                if (notizen.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.speaker_notes_off_outlined,
                              size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            s.notizKeine,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notizen.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final note = notizen[index];
                    return _NotizTile(
                      note: note,
                      onDelete: () => _deleteNote(context, ref, note),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNoteDialog(
    BuildContext context,
    WidgetRef ref,
    NoteType typ,
  ) async {
    final s = S.of(context);
    final controller = TextEditingController();
    final isAnruf = typ == NoteType.anruf;
    final isEmail = typ == NoteType.email;
    final icon = isAnruf
        ? Icons.phone_callback
        : isEmail
            ? Icons.email
            : Icons.note_add;
    final color = isAnruf
        ? AppTheme.successColor
        : isEmail
            ? Colors.blue
            : AppTheme.primaryColor;
    final title = isAnruf
        ? s.anrufProtokollieren
        : isEmail
            ? s.emailProtokollieren
            : s.notizHinzufuegen;
    final hint = isAnruf
        ? s.anrufPlaceholder
        : isEmail
            ? s.emailPlaceholder
            : s.notizPlaceholder;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.abbrechen),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(s.speichern),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final service = ref.read(firebaseServiceProvider);
      final note = PatientNote(
        id: '',
        patientId: patient.id,
        praxisId: patient.praxisId,
        inhalt: result,
        typ: typ,
        erstelltAm: DateTime.now(),
      );
      await service.addNotiz(note);

      if (context.mounted) {
        final msg = isAnruf
            ? s.anrufGespeichert
            : isEmail
                ? s.emailGespeichert
                : s.notizGespeichert;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteNote(
    BuildContext context,
    WidgetRef ref,
    PatientNote note,
  ) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.notizLoeschen),
        content: Text(s.notizLoeschenBestaetigung),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.abbrechen),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(s.loeschen),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(firebaseServiceProvider);
      await service.deleteNotiz(patient.praxisId, patient.id, note.id);
    }
  }
}

class _NoteAddButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NoteAddButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 20, color: AppTheme.primaryColor),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Rezept-Sektion
// ════════════════════════════════════════════════════════════════

class _RezeptSection extends StatelessWidget {
  final Patient patient;

  const _RezeptSection({required this.patient});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');

    // Warnung-Status
    final bool abgelaufen = patient.rezeptAbgelaufen;
    final bool laeuftAb = patient.rezeptLaeuftAb && !abgelaufen;
    final warnColor = abgelaufen
        ? AppTheme.errorColor
        : laeuftAb
            ? AppTheme.warningColor
            : null;

    return Card(
      color: warnColor != null
          ? warnColor.withValues(alpha: 0.05)
          : null,
      shape: warnColor != null
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: warnColor.withValues(alpha: 0.3),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: warnColor ?? AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.rezeptTitel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: warnColor ?? AppTheme.primaryColor,
                        ),
                  ),
                ),
                if (abgelaufen)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, size: 14, color: AppTheme.errorColor),
                        const SizedBox(width: 4),
                        Text(
                          s.rezeptAbgelaufen,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (laeuftAb)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppTheme.warningColor),
                        const SizedBox(width: 4),
                        Text(
                          s.rezeptLaeuftAb(patient.rezeptTageVerbleibend!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            if (!patient.hatRezept)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    s.rezeptKein,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else ...[
              _InfoTile(
                label: s.rezeptDatum,
                value: dateFormat.format(patient.rezeptDatum!),
              ),
              if (patient.rezeptGueltigBis != null)
                _InfoTile(
                  label: s.rezeptGueltigBis,
                  value:
                      '${dateFormat.format(patient.rezeptGueltigBis!)}${patient.rezeptTageVerbleibend != null ? ' (${patient.rezeptTageVerbleibend} Tage)' : ''}',
                ),
              if (patient.verordnungsMenge != null)
                _InfoTile(
                  label: s.rezeptVerordnungsMenge,
                  value: '${patient.verordnungsMenge} Einheiten',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Kontakt-Info Karte
// ════════════════════════════════════════════════════════════════

class _KontaktInfoCard extends StatelessWidget {
  final Patient patient;

  const _KontaktInfoCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');
    final ueberfaellig = patient.kontaktUeberfaellig;

    return Card(
      color: ueberfaellig
          ? AppTheme.warningColor.withValues(alpha: 0.05)
          : null,
      shape: ueberfaellig
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppTheme.warningColor.withValues(alpha: 0.3),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              ueberfaellig
                  ? Icons.warning_amber_rounded
                  : Icons.contact_phone_outlined,
              color:
                  ueberfaellig ? AppTheme.warningColor : AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.letzterKontakt,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ueberfaellig
                              ? AppTheme.warningColor
                              : AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patient.letzterKontakt != null
                        ? '${dateFormat.format(patient.letzterKontakt!)} (${patient.tageSeitLetztemKontakt} Tage)'
                        : s.keinKontakt,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ueberfaellig
                              ? AppTheme.warningColor
                              : Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            if (ueberfaellig)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.kontaktUeberfaellig,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotizTile extends StatelessWidget {
  final PatientNote note;
  final VoidCallback onDelete;

  const _NotizTile({
    required this.note,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (note.typ) {
      case NoteType.anruf:
        color = AppTheme.successColor;
        icon = Icons.phone_callback;
      case NoteType.statusAenderung:
        color = AppTheme.warningColor;
        icon = Icons.swap_horiz;
      case NoteType.email:
        color = Colors.blue;
        icon = Icons.email_outlined;
      case NoteType.rezept:
        color = Colors.purple;
        icon = Icons.receipt_long_outlined;
      case NoteType.dokument:
        color = Colors.indigo;
        icon = Icons.attach_file;
      case NoteType.notiz:
        color = AppTheme.primaryColor;
        icon = Icons.note_outlined;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.inhalt,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      note.typ.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      note.formatiertesDatum,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Dokumente-Sektion
// ════════════════════════════════════════════════════════════════

final _dokumentServiceProvider = Provider<DokumentService>((ref) => DokumentService());

final _dokumenteProvider = StreamProvider.family<List<Dokument>, String>((ref, patientId) {
  final praxisId = ref.watch(praxisIdProvider);
  if (praxisId == null || praxisId.isEmpty) return Stream.value([]);
  return ref.watch(_dokumentServiceProvider).getDokumente(praxisId, patientId);
});

class _DokumenteSection extends ConsumerWidget {
  final Patient patient;
  const _DokumenteSection({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dokumenteAsync = ref.watch(_dokumenteProvider(patient.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dokumente',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo,
                        ),
                  ),
                ),
                // Foto upload
                _DocAddButton(
                  icon: Icons.photo_camera_outlined,
                  tooltip: 'Foto hochladen',
                  onPressed: () => _pickAndUpload(context, ref, DokumentTyp.foto),
                ),
                const SizedBox(width: 4),
                // PDF upload
                _DocAddButton(
                  icon: Icons.picture_as_pdf_outlined,
                  tooltip: 'PDF hochladen',
                  onPressed: () => _pickAndUpload(context, ref, DokumentTyp.pdf),
                ),
              ],
            ),
            const Divider(height: 20),

            dokumenteAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Fehler: $e', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
              ),
              data: (dokumente) {
                if (dokumente.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Noch keine Dokumente', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: dokumente.map((doc) => _DokumentTile(
                    dokument: doc,
                    onDelete: () => _deleteDokument(context, ref, doc),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref, DokumentTyp typ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: typ == DokumentTyp.pdf ? FileType.custom : FileType.image,
        allowedExtensions: typ == DokumentTyp.pdf ? ['pdf'] : null,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      // Loading anzeigen
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wird hochgeladen...'), duration: Duration(seconds: 10)),
        );
      }

      final service = ref.read(_dokumentServiceProvider);
      await service.uploadDokument(
        bytes: file.bytes!,
        fileName: file.name,
        patientId: patient.id,
        praxisId: patient.praxisId,
        typ: typ,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} hochgeladen'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _deleteDokument(BuildContext context, WidgetRef ref, Dokument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dokument loeschen?'),
        content: Text('"${doc.name}" unwiderruflich loeschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Loeschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(_dokumentServiceProvider);
      await service.deleteDokument(
        praxisId: patient.praxisId,
        patientId: patient.id,
        dokumentId: doc.id,
        url: doc.url,
      );
    }
  }
}

class _DocAddButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _DocAddButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.indigo.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Tooltip(message: tooltip, child: Icon(icon, size: 20, color: Colors.indigo)),
        ),
      ),
    );
  }
}

class _DokumentTile extends StatelessWidget {
  final Dokument dokument;
  final VoidCallback onDelete;

  const _DokumentTile({required this.dokument, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isFoto = dokument.typ == DokumentTyp.foto;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _openDokument(dokument),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Thumbnail / Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isFoto ? Colors.blue.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isFoto
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(dokument.url, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.blue.shade300, size: 20)),
                      )
                    : Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 22),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dokument.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '${dokument.typ.label} · ${dokument.groesseText} · ${dokument.formatiertesDatum}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // Delete
              IconButton(
                icon: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDokument(Dokument doc) async {
    final uri = Uri.parse(doc.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
