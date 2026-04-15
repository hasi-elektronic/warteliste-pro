import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _localePrefsKey = 'app_locale';

/// Notifier fuer die aktuelle Sprache der App.
///
/// Standard ist Deutsch. Beim Start wird die zuletzt gespeicherte Wahl
/// aus [SharedPreferences] geladen.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('de')) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localePrefsKey);
      if (code != null && (code == 'de' || code == 'en')) {
        state = Locale(code);
      }
    } catch (_) {
      // ignore - bleibt bei Default
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localePrefsKey, locale.languageCode);
    } catch (_) {
      // ignore
    }
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());
