# WarteListe Pro

## Proje Bilgisi
- **App:** WarteListe Pro - Wartelisten-Management für Logopädie-Praxen
- **Paket:** `com.hasielektronic.warteliste_pro`
- **Firebase Projekt:** `warteliste-pro`
- **Web:** https://warteliste-pro.web.app
- **Teknoloji:** Flutter 3.x, Firebase (Firestore, Auth), Riverpod, Material Design 3
- **Sprache (UI):** Deutsch

## Teknik Yapı
- **State Management:** Riverpod (StateNotifierProvider)
- **Routing:** GoRouter
- **Charts:** fl_chart
- **Excel:** excel package (import/export)
- **Push:** Firebase Cloud Messaging

## Firebase Datenmodell
```
/users/{userId} - Benutzer mit role (admin/user), praxisId, praxisIds[]
/invites/{inviteId} - Einladungen fuer Mitarbeiter
/praxen/{praxisId} - Praxis-Daten
/praxen/{praxisId}/patienten/{id} - Patienten
/praxen/{praxisId}/therapeuten/{id} - Therapeuten
/praxen/{praxisId}/termine/{id} - Termine
/praxen/{praxisId}/tokens/{id} - FCM Tokens
```

## Mevcut Özellikler (Tamamlanan)
- ✅ Login / Registrierung (Firebase Auth Email/Password)
- ✅ Dashboard mit KPIs
- ✅ Warteliste (Tabs: Alle, Wartend, Platz gefunden, In Behandlung)
- ✅ Patient CRUD (Formular + Detail)
- ✅ Statistiken (fl_chart)
- ✅ Excel Import / Export
- ✅ Therapeuten-Verwaltung
- ✅ Einstellungen
- ✅ Multi-Standort Management (Admin kann mehrere Standorte verwalten)
- ✅ Admin/User Rollensystem (Admin sieht alles, User nur eigenen Standort)
- ✅ Mitarbeiter einladen per Email (Invite-System)
- ✅ Firestore Security Rules (praxisId + praxisIds Support)
- ✅ Web Deploy (Firebase Hosting)
- ✅ Android AAB Build + Play Store Upload

## Wichtige Dateien
- `lib/models/app_user.dart` - User-Modell mit Rollen
- `lib/providers/auth_provider.dart` - Auth + Role Provider
- `lib/providers/standort_provider.dart` - Multi-Standort Provider
- `lib/widgets/standort_switcher.dart` - Standort-Wechsel Widget
- `lib/services/firebase_service.dart` - Alle Firebase Operationen
- `lib/utils/constants.dart` - Stoerungsbilder (Logopaedie), Labels
- `lib/utils/theme.dart` - App Theme (Teal/Gruen Toene)
- `lib/l10n/strings.dart` - Alle UI-Strings (DE + EN)
- `scripts/upload_to_play.py` - Play Store Upload Script
- `firestore.rules` - Firestore Security Rules

## Build Kommandos
```bash
flutter build web --release          # Web Build
flutter build appbundle --release    # Android AAB
firebase deploy --only hosting --project warteliste-pro    # Web Deploy
firebase deploy --only firestore:rules --project warteliste-pro  # Rules Deploy
python3 scripts/upload_to_play.py build/app/outputs/bundle/release/app-release.aab --track internal --status draft
```

## Aktuelle Version
- pubspec.yaml: version 1.4.0+16

## Version 1.4.0 Neue Features
- Rezept-Verwaltung (Datum, Gueltig bis, Verordnungsmenge, Ablauf-Warnungen)
- Patienten-Prioritaet (Normal, Hoch, Dringend)
- Kontakt-Tracking (letzter Kontakt, ueberfaellig-Warnung >30 Tage)
- E-Mail-Protokollierung in Notizen
- Dashboard: Durchschnittliche Wartezeit, Rezept-Warnungen, Kontakt-Warnungen, Dringende Patienten
- Therapeut: Max. Patienten Kapazitaet, Fachgebiet
- Warteliste: Sortierung nach Prioritaet, Rezept-Warnung Badge
- Patient-Card: Prioritaet-Badge, Rezept-Ablauf Icon

## Nächste Schritte
- Push Notifications (FCM) implementierung
- App Icon iyilestirme (adaptive icon white background fix)
- Therapeut-Kapazitaet Dashboard Widget
