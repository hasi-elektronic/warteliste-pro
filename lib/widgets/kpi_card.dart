import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Wiederverwendbare KPI-Karte fuer das Dashboard.
///
/// Zeigt einen Titel, Wert, Icon und farbige obere Bordierung.
/// Mit Hover-Effekt (Desktop/Web) und dezenter Animation.
class KpiCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverable = widget.onTap != null;
    return MouseRegion(
      cursor:
          hoverable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => hoverable ? setState(() => _hover = true) : null,
      onExit: (_) => hoverable ? setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: _hover ? AppTheme.slate50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hover ? widget.color.withValues(alpha: 0.45) : AppTheme.slate300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.slate900
                  .withValues(alpha: _hover ? 0.12 : 0.06),
              blurRadius: _hover ? 14 : 6,
              offset: Offset(0, _hover ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.transparent,
            splashColor: widget.color.withValues(alpha: 0.08),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: widget.color, width: 3),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: widget.color, size: 24),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.value,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: widget.color,
                                letterSpacing: -0.3,
                              ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.title,
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.slate700,
                              fontWeight: FontWeight.w600,
                            ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
