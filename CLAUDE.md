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
/praxen/{praxisId} - Praxis-Daten, admins[] (UIDs der Standort-Admins)
/praxen/{praxisId}/patienten/{id} - Patienten
/praxen/{praxisId}/therapeuten/{id} - Therapeuten
/praxen/{praxisId}/aerzte/{id} - Arzt-Adressbuch (Briefe)
/praxen/{praxisId}/mitarbeiter/{uid} - Index fuer die Mitarbeiter-Anzeige
/praxen/{praxisId}/termine/{id} - Termine
/praxen/{praxisId}/tokens/{id} - FCM Tokens
```

### Zugriffsmodell (wichtig)
- **Zugriff** haengt an `users/{uid}.praxisIds` — ODER daran, dass der Nutzer
  in `praxen/{id}.admins` steht. Ein **Standort-Admin verliert seinen Zugriff
  nie**, auch wenn praxisIds den Eintrag verliert ("Standort entfernen").
- `role` ist **global** — andere Nutzer duerfen client-seitig NICHT umgestuft
  werden (sonst Admin-Rechte bei fremden Mandanten). "Admin dieses Standorts"
  laeuft ueber `praxen.admins` (`setStandortAdmin`).
- **`users` ist client-seitig NICHT per Query lesbar**: bei `list` ist
  `resource` in den Rules null, datenabhaengige Regeln sind dort nicht
  auswertbar. Darum der `mitarbeiter`-Index (Regel haengt nur am Pfad).
- Rules-Regressionstests: `scripts/rules_test.js`
  (`export JAVA_HOME=/opt/homebrew/opt/openjdk@21` →
  `firebase emulators:exec --only firestore --project warteliste-rules-test "node scripts/rules_test.js"`)
- Migrationen: `scripts/migrate_praxis_admins.js`, `scripts/migrate_mitarbeiter_index.js` (beide mit Dry-Run)

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
- pubspec.yaml: version **1.5.2+25**

## Version 1.5.1 Änderungen (seit 1.4.0)
- iOS Compliance: NSCameraUsageDescription + NSMicrophoneUsageDescription entfernt (nicht verwendet, App-Review-Risiko)
- ITSAppUsesNonExemptEncryption = false (Export Compliance)
- Dashboard UI Verbesserungen
- Design-Refresh + Web-Branding
- Security Hardening: R2 Worker Auth + Firestore Self-Elevation Fix

## Version 1.4.0 Features (historisch)
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
- App Icon: adaptive icon white background fix
- Therapeut-Kapazitaet Dashboard Widget
- Große Screen-Dateien aufteilen (einstellungen_screen.dart 1740 lines, patient_detail_screen.dart 1502 lines)
- Test Coverage erhöhen (aktuell ~2%, Placeholder test)
- StreamProvider'a autoDispose eklenmesi (Memory Leak-Vermeidung)
- go_router Migration (paket installiert, aber Navigator 1.0 aktiv)
