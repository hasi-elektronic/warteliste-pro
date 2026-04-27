# Release Notes — WarteListe Pro v1.5.1+24

## Play Store (Deutsch, max 500 Zeichen)

```
Version 1.5.1 bringt ein frisches Design und mehr Sicherheit:

• Neues Erscheinungsbild mit klarerer Struktur
• Verbesserte Dashboard-Übersicht
• Schnellere Ladezeiten beim Patientenwechsel
• iOS/Android-Optimierungen für aktuelle Geräte
• Härtere Sicherheit für Dokumenten-Upload
• Stabilität bei Rollenverwaltung verbessert

Ihr Feedback hat viele dieser Änderungen inspiriert – danke!
```

**Länge**: ~380 Zeichen ✅

---

## App Store (Deutsch, max 4000 Zeichen — großzügiger)

```
Version 1.5.1 — Frischeres Design und mehr Sicherheit

Was ist neu:

• Design-Refresh: Klarere Struktur, besserer Kontrast, modernere Typografie
• Dashboard: Übersichtlichere Darstellung der Wartezeiten und Prioritäten
• Performance: Schnellere Ladezeiten beim Wechseln zwischen Patienten
• iOS-Optimierungen: Volle Kompatibilität mit iOS 17+ und iPadOS
• Sicherheit: Verbesserte Authentifizierung für den Dokumenten-Upload (Cloudflare R2 Worker)
• Rollenverwaltung: Stabilere Verteilung von Admin-, Therapeut- und Assistenz-Rechten

Kleine Fehlerbehebungen:
- Dashboard zeigt jetzt alle dringenden Patienten korrekt an
- Patient-Detail-Ansicht lädt schneller bei vielen Notizen
- Excel-Import ist robuster bei ungewöhnlichen Zellformaten

Danke für Ihr Vertrauen und Feedback!
Haben Sie Fragen oder Anregungen? Schreiben Sie uns an info@hasi-elektronik.de
```

**Länge**: ~1040 Zeichen ✅

---

## TestFlight (intern, kann technischer sein)

```
v1.5.1+24 — iOS Compliance & Security Hardening

Änderungen:
- NSCameraUsageDescription + NSMicrophoneUsageDescription entfernt
  (waren im Info.plist deklariert, aber die Features sind nicht implementiert —
   App-Review hätte das als "declared but not used" flaggen können)
- ITSAppUsesNonExemptEncryption = false (Export Compliance explizit gesetzt)
- R2 Worker Auth Hardening (d6780eb)
- Firestore Self-Elevation Fix (d6780eb)
- Dashboard UI Refactorings

Testing-Fokus:
- Excel-Import (NSPhotoLibrary — einzige noch aktive Permission)
- Dokumenten-Upload (R2 Worker Endpoint)
- Login mit Rollenverwaltung (Admin / Therapeut / Assistenz)
```

---

## Checklist vor Submit

- [ ] `pubspec.yaml` version = 1.5.1+24 ✓ bereits gesetzt
- [ ] iOS: `ios/Runner/Info.plist` — Camera + Microphone Permissions entfernt ✓
- [ ] Android: `targetSdkVersion` = 35 (Google Play 2026 Anforderung) — zu verifizieren
- [ ] Datenschutz-URL erreichbar: https://warteliste-pro-legal.pages.dev/datenschutz.html — zu verifizieren
- [ ] 6.7" iPhone Screenshots (1290x2796) — optional 2024+ empfohlen
- [ ] Release Notes hier kopierbar für Console
