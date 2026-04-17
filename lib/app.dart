import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'router.dart';
import 'utils/theme.dart';
import 'utils/constants.dart';
import 'l10n/strings.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/patienten_provider.dart';
import 'providers/standort_provider.dart';
import 'providers/theme_provider.dart';

class WartelisteApp extends ConsumerStatefulWidget {
  const WartelisteApp({super.key});

  @override
  ConsumerState<WartelisteApp> createState() => _WartelisteAppState();
}

class _WartelisteAppState extends ConsumerState<WartelisteApp> {
  @override
  void initState() {
    super.initState();
    _loadPraxisId();
  }

  Future<void> _loadPraxisId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final service = ref.read(firebaseServiceProvider);
      final praxisId = await service.currentPraxisId;
      if (praxisId != null && mounted) {
        ref.read(praxisIdProvider.notifier).state = praxisId;
      }
      // User-Profil mit Rolle laden
      if (mounted) {
        ref.read(appUserProvider.notifier).load();
      }
      // Offene Einladungen einloesen
      await service.redeemInvites();
      // Standorte laden (triggert den Provider)
      if (mounted) {
        ref.read(standorteProvider.notifier).load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      locale: locale,
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) {
        // Responsive Web Layout:
        // < 600px: full width (Mobil)
        // 600-1400px: zentriert mit max 720px
        // > 1400px: zentriert mit max 1040px
        final width = MediaQuery.of(context).size.width;

        if (width <= 600 || child == null) {
          return child ?? const SizedBox();
        }

        final maxW = width > 1400 ? 1040.0 : width > 900 ? 820.0 : 680.0;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final outerBg = isDark ? const Color(0xFF020617) : AppTheme.slate200;
        final borderColor = isDark ? const Color(0xFF1F2937) : AppTheme.slate300;

        return Container(
          color: outerBg,
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxW),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border.symmetric(
                  vertical: BorderSide(color: borderColor, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.slate900.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
