import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../utils/theme.dart';

/// Kleines farbiges Badge, das den Patienten-Status anzeigt.
///
/// Chip-Stil: klein, abgerundet, farbig passend zum Status.
class StatusBadge extends StatelessWidget {
  final PatientStatus status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  Color get _backgroundColor {
    switch (status) {
      case PatientStatus.wartend:
        return AppTheme.statusWartend;
      case PatientStatus.platzGefunden:
        return AppTheme.statusPlatzGefunden;
      case PatientStatus.inBehandlung:
        return AppTheme.statusInBehandlung;
      case PatientStatus.abgeschlossen:
        return AppTheme.statusAbgeschlossen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _backgroundColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _backgroundColor,
        ),
      ),
    );
  }
}
