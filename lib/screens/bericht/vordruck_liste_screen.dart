import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bericht.dart';
import '../../models/praxis.dart';
import '../../models/vordruck.dart';
import '../../models/weil_vorlagen.dart';
import '../../providers/standort_provider.dart';
import '../../services/vordruck_service.dart';
import '../../utils/theme.dart';
import '../../widgets/app_header.dart';
import 'bericht_form_screen.dart';

/// Liste der offiziellen Vordrucke (PDF/DOCX) — Original-Dokumente,
/// werden unverändert geliefert.
class VordruckListeScreen extends ConsumerWidget {
  const VordruckListeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final praxis = ref.watch(aktivesPraxisProvider);
    final vordrucke = VordruckService.visibleFor(praxis);

    // Gruppen nach Reihenfolge
    final groupiert = <String, List<Vordruck>>{};
    for (final v in vordrucke) {
      groupiert.putIfAbsent(v.gruppe, () => []).add(v);
    }

    return Scaffold(
      backgroundColor: AppTheme.slate100,
      appBar: const AppHeader(
        title: 'Vordrucke',
        icon: Icons.folder_special_outlined,
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Hinweis ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Offizielle Vordrucke',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Diese Dokumente sind die Original-Vorlagen — sie '
                        'können heruntergeladen oder gedruckt und manuell '
                        'bzw. mit einem PDF-Editor ausgefüllt werden.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.slate700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Gruppen ────────────────────────────────────────────
          for (final entry in groupiert.entries) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ...entry.value.map((v) => _VordruckCard(
                  vordruck: v,
                  praxis: praxis,
                )),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _VordruckCard extends StatefulWidget {
  final Vordruck vordruck;
  final Praxis? praxis;

  const _VordruckCard({required this.vordruck, this.praxis});

  @override
  State<_VordruckCard> createState() => _VordruckCardState();
}

class _VordruckCardState extends State<_VordruckCard> {
  bool _busy = false;
  bool _hover = false;

  Future<void> _drucken() async {
    setState(() => _busy = true);
    try {
      await VordruckService.drucken(widget.vordruck, widget.praxis);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _teilen() async {
    setState(() => _busy = true);
    try {
      await VordruckService.teilen(widget.vordruck, widget.praxis);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Öffnet den Bericht-Editor mit dem Fließtext dieser Vorlage vorbelegt.
  /// Der Patient wird im Formular ausgewählt; nach dem Speichern ist der
  /// Bericht wie jeder andere bearbeitbar.
  void _alsBerichtAusfuellen(BuildContext context) {
    final vorlage = weilVorlageById(widget.vordruck.id);
    if (vorlage == null) return;
    final kategorie = BerichtKategorie.values.firstWhere(
      (k) => k.name == vorlage.kategorie,
      orElse: () => BerichtKategorie.verlaufsbericht,
    );
    Navigator.of(context).pushNamed(
      '/bericht/neu',
      arguments: BerichtFormArgs(
        kategorie: kategorie,
        vorlageTitel: vorlage.titel,
        vorlageText: vorlage.body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vordruck;
    final isDocx = v.istWord;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hover
                ? v.color.withValues(alpha: 0.4)
                : AppTheme.slate200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.slate900
                  .withValues(alpha: _hover ? 0.10 : 0.04),
              blurRadius: _hover ? 14 : 6,
              offset: Offset(0, _hover ? 3 : 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon ─────────────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: v.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(v.icon, color: v.color, size: 22),
              ),
              const SizedBox(width: 14),

              // ── Text ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            v.titel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate900,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.slate100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            v.erweiterung.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.slate700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.beschreibung,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.slate600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Aktionen ───────────────────────────────
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (v.ausfuellenRoute != null)
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context)
                                .pushNamed(v.ausfuellenRoute!),
                            icon: const Icon(Icons.edit_note, size: 16),
                            label: const Text('Ausfüllen'),
                            style: FilledButton.styleFrom(
                              backgroundColor: v.color,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        // In-App als Bericht ausfüllen (Weil-Vorlagen)
                        if (weilVorlageById(v.id) != null)
                          FilledButton.icon(
                            onPressed: () => _alsBerichtAusfuellen(context),
                            icon: const Icon(Icons.edit_note, size: 16),
                            label: const Text('Als Bericht ausfüllen'),
                            style: FilledButton.styleFrom(
                              backgroundColor: v.color,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        if (!isDocx)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _drucken,
                            icon: _busy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.print_outlined,
                                    size: 16),
                            label: Text(_busy ? 'Lädt …' : 'Leer drucken'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _teilen,
                          icon: const Icon(Icons.download, size: 16),
                          label: Text(
                              isDocx ? 'Word-Datei laden' : 'Original laden'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
