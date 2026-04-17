import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// WarteListe Pro Theme — modernes professionelles SaaS-Design.
/// Tiefes Teal als Brand, Slate-Palette fuer neutrale Flaechen,
/// klare Typographie-Hierarchie mit hohem Kontrast.
class AppTheme {
  AppTheme._();

  // ──────────────────────────────────────────────
  // Farb-Palette (Tailwind-inspiriert)
  // ──────────────────────────────────────────────

  // Brand (Teal)
  static const Color primaryColor = Color(0xFF0F766E); // teal-700
  static const Color primaryLight = Color(0xFF14B8A6); // teal-500
  static const Color primaryDark = Color(0xFF115E59);  // teal-800
  static const Color primarySurface = Color(0xFFF0FDFA); // teal-50 bg tint

  // Accent
  static const Color accentColor = Color(0xFF0891B2); // cyan-600

  // Semantische Farben
  static const Color errorColor = Color(0xFFDC2626);   // red-600
  static const Color successColor = Color(0xFF059669); // emerald-600
  static const Color warningColor = Color(0xFFD97706); // amber-600

  // Slate (Neutral)
  static const Color slate50  = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Hintergrund / Karten — kraeftigere Kontraste
  static const Color surfaceColor = slate100;  // Scaffold (staerker vs. Karten)
  static const Color cardColor = Colors.white;
  static const Color borderColor = slate300;    // Kartenborder (gut sichtbar)
  static const Color borderSubtle = slate200;   // feine Trenner

  // Status-Farben (Patienten-Workflow)
  static const Color statusWartend = Color(0xFFEA580C);       // orange-600
  static const Color statusPlatzGefunden = Color(0xFF2563EB); // blue-600
  static const Color statusInBehandlung = Color(0xFF059669);  // emerald-600
  static const Color statusAbgeschlossen = Color(0xFF64748B); // slate-500

  // ──────────────────────────────────────────────
  // Color Scheme
  // ──────────────────────────────────────────────

  static final ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: primarySurface,
    onPrimaryContainer: primaryDark,
    secondary: accentColor,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE0F2FE),
    onSecondaryContainer: Color(0xFF075985),
    tertiary: Color(0xFF7C3AED),
    onTertiary: Colors.white,
    error: errorColor,
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Colors.white,
    onSurface: slate900,
    surfaceContainerHighest: slate100,
    onSurfaceVariant: slate600,
    outline: slate300,
    outlineVariant: slate200,
    shadow: Color(0x1A0F172A),
    scrim: Color(0x66000000),
    inverseSurface: slate900,
    onInverseSurface: slate100,
    inversePrimary: primaryLight,
  );

  // Gemeinsame Schrift — Inter wirkt modern & professionell
  static TextTheme _textTheme(Color onSurface, Color onSurfaceVariant) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displayMedium: base.displayMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displaySmall: base.displaySmall?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
      headlineLarge: base.headlineLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: base.headlineMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(color: onSurface, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: onSurface, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(color: onSurfaceVariant, height: 1.4, fontWeight: FontWeight.w500),
      labelLarge: base.labelLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
      labelMedium: base.labelMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(color: onSurfaceVariant, fontWeight: FontWeight.w600),
    );
  }

  // ──────────────────────────────────────────────
  // Light Theme
  // ──────────────────────────────────────────────

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      textTheme: _textTheme(slate900, slate700),
      scaffoldBackgroundColor: surfaceColor,

      // Globaler Hover / Focus / Highlight
      hoverColor: primaryColor.withValues(alpha: 0.06),
      focusColor: primaryColor.withValues(alpha: 0.10),
      splashColor: primaryColor.withValues(alpha: 0.12),
      highlightColor: primaryColor.withValues(alpha: 0.06),

      // AppBar — weiss mit farbigem Text (modern SaaS look)
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: slate900,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: slate900,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: slate700, size: 22),
        actionsIconTheme: const IconThemeData(color: slate700, size: 22),
        shape: const Border(
          bottom: BorderSide(color: slate300, width: 1),
        ),
      ),

      // Card — weiss + klare Border + dezenter Schatten
      cardTheme: CardThemeData(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: slate900.withValues(alpha: 0.10),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),

      // ElevatedButton — primary CTA
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: slate200,
          disabledForegroundColor: slate400,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return slate200;
            if (states.contains(WidgetState.pressed)) return const Color(0xFF0B5952);
            if (states.contains(WidgetState.hovered)) return primaryDark;
            return primaryColor;
          }),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate700,
          side: const BorderSide(color: slate300, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return slate100;
            return Colors.white;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return const BorderSide(color: slate400, width: 1);
            }
            return const BorderSide(color: slate300, width: 1);
          }),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Input — klare sichtbare Borders
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hoverColor: slate50,
        labelStyle: GoogleFonts.inter(color: slate700, fontSize: 14),
        floatingLabelStyle: GoogleFonts.inter(color: primaryColor, fontSize: 14, fontWeight: FontWeight.w600),
        hintStyle: GoogleFonts.inter(color: slate400, fontSize: 14),
        prefixIconColor: slate600,
        suffixIconColor: slate600,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: slate400, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: slate400, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),

      // Chip — besser sichtbar
      chipTheme: ChipThemeData(
        backgroundColor: slate200,
        selectedColor: primarySurface,
        disabledColor: slate100,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: slate800),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: primaryDark),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: const BorderSide(color: slate300, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: slate300,
        thickness: 1,
        space: 1,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: slate900.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: slate900),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: slate700, height: 1.5),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: slate800,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        actionTextColor: primaryLight,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      // TabBar — mit dunkler AppBar-Farbe
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: slate500,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: borderColor,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // NavigationBar (Bottom-Nav)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primarySurface,
        elevation: 3,
        shadowColor: slate900.withValues(alpha: 0.08),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? primaryColor : slate500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryColor : slate500,
            size: 22,
          );
        }),
      ),

      // ListTile — mit Hover (hoverColor kommt aus global ThemeData.hoverColor)
      listTileTheme: ListTileThemeData(
        iconColor: slate600,
        textColor: slate900,
        tileColor: Colors.white,
        selectedTileColor: primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Icon
      iconTheme: const IconThemeData(color: slate700, size: 22),

      // Progress
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: slate200,
        circularTrackColor: slate200,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return slate300;
        }),
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        textStyle: GoogleFonts.inter(fontSize: 14, color: slate900),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: slate800,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Dark Theme
  // ──────────────────────────────────────────────

  static final ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryLight,
    onPrimary: slate900,
    primaryContainer: primaryDark,
    onPrimaryContainer: Color(0xFFCCFBF1),
    secondary: Color(0xFF22D3EE),
    onSecondary: slate900,
    secondaryContainer: Color(0xFF164E63),
    onSecondaryContainer: Color(0xFFCFFAFE),
    tertiary: Color(0xFFA78BFA),
    onTertiary: slate900,
    error: Color(0xFFF87171),
    onError: slate900,
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFECACA),
    surface: Color(0xFF0B1220),
    onSurface: slate100,
    surfaceContainerHighest: slate800,
    onSurfaceVariant: slate400,
    outline: slate700,
    outlineVariant: slate800,
    shadow: Colors.black,
    scrim: Color(0xAA000000),
    inverseSurface: slate100,
    onInverseSurface: slate900,
    inversePrimary: primaryColor,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      textTheme: _textTheme(slate100, slate400),
      scaffoldBackgroundColor: const Color(0xFF0B1220),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF111827),
        foregroundColor: slate100,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: slate100,
        ),
        iconTheme: const IconThemeData(color: slate300, size: 22),
        shape: const Border(bottom: BorderSide(color: Color(0xFF1F2937), width: 1)),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1F2937), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: slate900,
        elevation: 2,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: slate900,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate200,
          side: const BorderSide(color: slate600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryLight),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        labelStyle: GoogleFonts.inter(color: slate400, fontSize: 14),
        floatingLabelStyle: GoogleFonts.inter(color: primaryLight, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.inter(color: slate500, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF374151), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF374151), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFF87171), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1F2937),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: slate200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        side: const BorderSide(color: Color(0xFF374151), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      dividerTheme: const DividerThemeData(color: Color(0xFF1F2937), thickness: 1, space: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: slate100,
        contentTextStyle: GoogleFonts.inter(color: slate900, fontSize: 14),
        actionTextColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: primaryLight,
        unselectedLabelColor: slate500,
        indicatorColor: primaryLight,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: const Color(0xFF1F2937),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryDark,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: slate400,
        textColor: slate100,
      ),

      iconTheme: const IconThemeData(color: slate300, size: 22),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryLight,
        linearTrackColor: Color(0xFF1F2937),
        circularTrackColor: Color(0xFF1F2937),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF1F2937), width: 1),
        ),
        textStyle: GoogleFonts.inter(fontSize: 14, color: slate100),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Hilfsmethoden
  // ──────────────────────────────────────────────

  /// Gibt die Farbe fuer einen Patienten-Status zurueck.
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'wartend':
        return statusWartend;
      case 'platz gefunden':
      case 'platzgefunden':
        return statusPlatzGefunden;
      case 'in behandlung':
      case 'inbehandlung':
        return statusInBehandlung;
      case 'abgeschlossen':
        return statusAbgeschlossen;
      default:
        return slate500;
    }
  }

  /// Hintergrund-Tint fuer Status-Chips.
  static Color statusSurfaceColor(String status) {
    final base = statusColor(status);
    return base.withValues(alpha: 0.1);
  }
}
