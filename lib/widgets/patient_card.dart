import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/patient.dart';
import '../utils/theme.dart';
import 'status_badge.dart';

/// Wiederverwendbare Patienten-Karte fuer die Warteliste.
///
/// Zeigt Name, Stoerungsbild, Anmeldedatum, Wartezeit, Status-Badge,
/// Versicherungs-Badge und einen Telefon-Button.
class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<PatientStatus>? onStatusChanged;

  const PatientCard({
    super.key,
    required this.patient,
    this.onTap,
    this.onDelete,
    this.onStatusChanged,
  });

  Future<void> _callPatient() async {
    final uri = Uri(scheme: 'tel', path: patient.telefon);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');

    final tage = patient.wartezeitInTagen;
    final isKritisch = tage > 180 && patient.status == PatientStatus.wartend;
    final isWarnung = tage > 90 && patient.status == PatientStatus.wartend;
    final borderColor = isKritisch
        ? AppTheme.errorColor
        : isWarnung
            ? AppTheme.warningColor
            : Colors.transparent;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: isWarnung
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(color: borderColor, width: 4),
                  ),
                )
              : null,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar mit Warnung ──
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isKritisch
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : isWarnung
                            ? AppTheme.warningColor.withValues(alpha: 0.1)
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      _initials(patient),
                      style: TextStyle(
                        color: isKritisch
                            ? AppTheme.errorColor
                            : isWarnung
                                ? AppTheme.warningColor
                                : AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isWarnung)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isKritisch
                              ? Icons.error
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: borderColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Versicherung
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patient.vollstaendigerName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _VersicherungBadge(
                          versicherung: patient.versicherung,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Stoerungsbild + Badges
                    Row(
                      children: [
                        if (patient.stoerungsbild.isNotEmpty)
                          Expanded(
                            child: Text(
                              patient.stoerungsbild,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (patient.stoerungsbild.isEmpty)
                          const Expanded(child: SizedBox()),
                        if (patient.prioritaet !=
                            PatientPrioritaet.normal) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: patient.prioritaet ==
                                      PatientPrioritaet.dringend
                                  ? AppTheme.errorColor
                                      .withValues(alpha: 0.1)
                                  : AppTheme.warningColor
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              patient.prioritaet.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: patient.prioritaet ==
                                        PatientPrioritaet.dringend
                                    ? AppTheme.errorColor
                                    : AppTheme.warningColor,
                              ),
                            ),
                          ),
                        ],
                        if (patient.rezeptLaeuftAb) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.receipt_long,
                            size: 14,
                            color: patient.rezeptAbgelaufen
                                ? AppTheme.errorColor
                                : AppTheme.warningColor,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Anmeldedatum + Wartezeit
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(patient.anmeldung),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          isKritisch
                              ? Icons.error_outline
                              : isWarnung
                                  ? Icons.warning_amber_rounded
                                  : Icons.access_time,
                          size: 14,
                          color: _wartezeitColor(tage),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Seit $tage Tagen',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _wartezeitColor(tage),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ── Rechte Seite: Status + Telefon ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: patient.status),
                  const SizedBox(height: 8),
                  if (patient.telefon.isNotEmpty)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        onPressed: _callPatient,
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppTheme.successColor.withValues(alpha: 0.1),
                          foregroundColor: AppTheme.successColor,
                        ),
                        tooltip: 'Anrufen',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
    return Colors.grey.shade600;
  }
}

/// Kleines Badge fuer die Versicherungsart.
class _VersicherungBadge extends StatelessWidget {
  final String versicherung;

  const _VersicherungBadge({required this.versicherung});

  @override
  Widget build(BuildContext context) {
    final isPrivat = versicherung.toLowerCase() == 'privat';
    final color = isPrivat ? Colors.purple : Colors.blue;
    final label = isPrivat ? 'Privat' : 'KK';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
