import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../models/bericht.dart';
import '../../models/bericht_anhang.dart';
import '../../providers/patienten_provider.dart';
import '../../providers/standort_provider.dart';
import '../../services/bericht_pdf_service.dart';
import '../../services/bericht_upload_service.dart';
import '../../services/praxis_briefpapier.dart';
import '../../utils/theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bericht_rich_editor.dart';
import 'bericht_form_screen.dart';

/// Liste aller Berichte einer Praxis mit Filter, Suche und Schnellzugriff
/// auf Detail-/Bearbeiten-Ansichten.
class BerichteListeScreen extends ConsumerStatefulWidget {
  const BerichteListeScreen({super.key});

  @override
  ConsumerState<BerichteListeScreen> createState() =>
      _BerichteListeScreenState();
}

class _BerichteListeScreenState extends ConsumerState<BerichteListeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  BerichtKategorie? _kategorieFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncBerichte = ref.watch(berichteProvider);
    return Scaffold(
      appBar: const AppHeader(
        title: 'Berichte',
        icon: Icons.menu_book_outlined,
        showBackButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Neuer Bericht'),
      ),
      body: Column(
        children: [
          // ── Suchleiste ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Berichte durchsuchen …',
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
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),

          // ── Kategorie-Filter ──
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _buildFilterChip(
                  label: 'Alle',
                  isActive: _kategorieFilter == null,
                  onTap: () => setState(() => _kategorieFilter = null),
                ),
                const SizedBox(width: 8),
                ...BerichtKategorie.values.map((k) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: k.label,
                        icon: _iconFor(k),
                        isActive: _kategorieFilter == k,
                        onTap: () => setState(
                            () => _kategorieFilter = _kategorieFilter == k ? null : k),
                      ),
                    )),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Liste ──
          Expanded(
            child: asyncBerichte.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorBox(error: e),
              data: (all) {
                final filtered = all.where((b) {
                  if (_kategorieFilter != null && b.kategorie != _kategorieFilter) {
                    return false;
                  }
                  if (_query.isEmpty) return true;
                  return b.titel.toLowerCase().contains(_query) ||
                      b.inhaltText.toLowerCase().contains(_query) ||
                      (b.patientName?.toLowerCase().contains(_query) ?? false) ||
                      b.authorEmail.toLowerCase().contains(_query);
                }).toList();
                if (filtered.isEmpty) {
                  return _EmptyState(hasFilter: _kategorieFilter != null || _query.isNotEmpty);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) =>
                      _BerichtCard(bericht: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).pushNamed(
      '/bericht/neu',
      arguments: const BerichtFormArgs(),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      avatar: icon != null
          ? Icon(icon, size: 14,
              color: isActive ? AppTheme.primaryColor : AppTheme.slate600)
          : null,
      selected: isActive,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: isActive ? AppTheme.primaryColor : AppTheme.slate700,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.12),
      showCheckmark: false,
      side: BorderSide(
        color: isActive
            ? AppTheme.primaryColor.withValues(alpha: 0.6)
            : AppTheme.slate300,
      ),
    );
  }

  static IconData _iconFor(BerichtKategorie k) {
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
}

/// Eine Bericht-Karte in der Liste.
class _BerichtCard extends ConsumerWidget {
  final Bericht bericht;
  const _BerichtCard({required this.bericht});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd.MM.yyyy · HH:mm');
    final color = _colorFor(bericht.kategorie);
    final previewSrc = bericht.inhaltText.isNotEmpty
        ? bericht.inhaltText
        : bericht.inhalt;
    final preview = previewSrc.length > 140
        ? '${previewSrc.substring(0, 140)}…'
        : previewSrc;
    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Kategorie-Badge + Datum
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _BerichteListeScreenState._iconFor(bericht.kategorie),
                          size: 12,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          bericht.kategorie.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time,
                      size: 12, color: AppTheme.slate500),
                  const SizedBox(width: 4),
                  Text(
                    fmt.format(bericht.erstelltAm),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.slate600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Titel
              Text(
                bericht.titel.isEmpty ? '(ohne Titel)' : bericht.titel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Patient + Author
              Row(
                children: [
                  if (bericht.patientName != null &&
                      bericht.patientName!.isNotEmpty) ...[
                    const Icon(Icons.person_outline,
                        size: 14, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        bericht.patientName!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  const Icon(Icons.account_circle_outlined,
                      size: 14, color: AppTheme.slate500),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      bericht.authorName ?? bericht.authorEmail,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.slate600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Inhalt-Preview
              Text(
                preview,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate700,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFor(BerichtKategorie k) {
    switch (k) {
      case BerichtKategorie.brief:
        return const Color(0xFF1A3FA0); // Menauer-Blau
      case BerichtKategorie.verlaufsbericht:
        return AppTheme.successColor;
      case BerichtKategorie.anamnese:
        return AppTheme.primaryColor;
      case BerichtKategorie.telefonat:
        return AppTheme.accentColor;
      case BerichtKategorie.uebergabe:
        return AppTheme.warningColor;
      case BerichtKategorie.allgemein:
        return AppTheme.slate500;
    }
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BerichtDetailSheet(bericht: bericht),
    );
  }
}

class _BerichtDetailSheet extends ConsumerWidget {
  final Bericht bericht;
  const _BerichtDetailSheet({required this.bericht});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd.MM.yyyy · HH:mm');
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Kategorie + Datum
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bericht.kategorie.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  fmt.format(bericht.erstelltAm),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Titel
            Text(
              bericht.titel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 4),
            // Verfasser + Patient
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (bericht.patientName != null &&
                    bericht.patientName!.isNotEmpty)
                  _MetaItem(
                    icon: Icons.person_outline,
                    label: bericht.patientName!,
                    color: AppTheme.primaryColor,
                  ),
                _MetaItem(
                  icon: Icons.account_circle_outlined,
                  label: bericht.authorName ?? bericht.authorEmail,
                  color: AppTheme.slate600,
                ),
              ],
            ),
            const Divider(height: 24),
            // Inhalt (Rich Text)
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BerichtRichViewer(inhalt: bericht.inhalt),
                    if (bericht.anhaenge.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.attach_file,
                              size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            'Anhänge (${bericht.anhaenge.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...bericht.anhaenge.map(
                          (a) => _AnhangViewTile(anhang: a)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // PDF-Aktionen
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportPdf(context, ref, share: false),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Drucken'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportPdf(context, ref, share: true),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('PDF teilen'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Bearbeiten / Löschen
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.errorColor, size: 18),
                    label: const Text('Löschen',
                        style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(
                        '/bericht/bearbeiten',
                        arguments: BerichtFormArgs(bericht: bericht),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Bearbeiten'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref,
      {required bool share}) async {
    try {
      final aktivePraxis = ref.read(aktivesPraxisProvider);
      final briefpapier =
          await PraxisBriefpapierService.forPraxis(aktivePraxis);
      if (share) {
        await BerichtPdfService.teileBericht(
          bericht: bericht,
          briefpapier: briefpapier,
        );
      } else {
        await BerichtPdfService.druckeBericht(
          bericht: bericht,
          briefpapier: briefpapier,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF-Export fehlgeschlagen: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bericht löschen?'),
        content: Text('"${bericht.titel}" endgültig löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final svc = ref.read(berichtServiceProvider);
      await svc.deleteBericht(bericht.praxisId, bericht.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 60,
              color: AppTheme.slate300,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilter
                  ? 'Keine Berichte gefunden'
                  : 'Noch keine Berichte',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFilter
                  ? 'Filter zurücksetzen oder Suchbegriff ändern'
                  : 'Mit dem + Button rechts unten den ersten Bericht anlegen',
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.slate500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final Object error;
  const _ErrorBox({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Fehler beim Laden: $error',
          style: const TextStyle(color: AppTheme.errorColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _AnhangViewTile extends StatelessWidget {
  final BerichtAnhang anhang;
  const _AnhangViewTile({required this.anhang});

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

  Future<void> _open() async {
    try {
      final signed = await BerichtUploadService.getSignedUrl(anhang.url);
      final uri = Uri.parse(signed);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {/* silent */}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _open,
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
                  width: 32, height: 32,
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
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                const Icon(Icons.open_in_new,
                    size: 16, color: AppTheme.slate500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
