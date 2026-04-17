import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Einheitlicher App-Header fuer alle Seiten.
///
/// Layout: [Logo · Markenname] │ [Seiten-Icon · Titel]                [Actions]
/// Weisser Hintergrund, dezente Unterkante. PreferredSize: 64px.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData? icon;
  final List<Widget> actions;
  final Widget? leading;
  final bool showBackButton;

  const AppHeader({
    super.key,
    required this.title,
    this.icon,
    this.actions = const [],
    this.leading,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context) && showBackButton;
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: AppTheme.slate300, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppTheme.slate700,
                      tooltip: 'Zurueck',
                    )
                  else if (leading != null)
                    leading!,

                  // Brand-Block: Logo + WarteListe Pro
                  _BrandBlock(
                    onTap: () {
                      // optional: navigate to root
                    },
                  ),

                  const SizedBox(width: 10),
                  // Trenner
                  Container(
                    width: 1,
                    height: 24,
                    color: AppTheme.slate300,
                  ),
                  const SizedBox(width: 12),

                  // Seiten-Icon + Titel
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate800,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Actions (right-aligned)
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBlock extends StatefulWidget {
  final VoidCallback? onTap;
  const _BrandBlock({this.onTap});

  @override
  State<_BrandBlock> createState() => _BrandBlockState();
}

class _BrandBlockState extends State<_BrandBlock> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.slate100 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient-Logo
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.assignment_turned_in_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.slate900,
                        letterSpacing: -0.3,
                      ),
                      children: [
                        TextSpan(text: 'WarteListe'),
                        TextSpan(
                          text: ' Pro',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Praxis-Management',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.slate500,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
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
}

/// Kompaktes Header-Action-Icon mit Hover.
class HeaderIconAction extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final Color? badgeColor;

  const HeaderIconAction({
    super.key,
    required this.icon,
    this.tooltip,
    this.onTap,
    this.badgeColor,
  });

  @override
  State<HeaderIconAction> createState() => _HeaderIconActionState();
}

class _HeaderIconActionState extends State<HeaderIconAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _hover ? AppTheme.slate100 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(widget.icon,
                  size: 20,
                  color: _hover
                      ? AppTheme.primaryColor
                      : AppTheme.slate700),
              if (widget.badgeColor != null)
                Positioned(
                  top: 8,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}
