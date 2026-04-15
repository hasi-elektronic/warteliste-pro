# Firebase Setup - WarteListe Pro

## 1. Firebase-Projekt erstellen

1. Gehe zu https://console.firebase.google.com
2. "Projekt hinzufuegen" klicken
3. Projektname: `warteliste-pro`
4. Google Analytics: optional (kann spaeter aktiviert werden)

## 2. Android-App hinzufuegen

1. Im Firebase-Projekt: "Android-App hinzufuegen"
2. Android-Paketname: `com.hasielektronic.warteliste_pro`
3. App-Nickname: `WarteListe Pro`
4. `google-services.json` herunterladen
5. Datei in `android/app/google-services.json` ablegen

## 3. Firebase-Dienste aktivieren

### Authentication
1. Firebase Console > Authentication > "Los geht's"
2. "E-Mail/Passwort" aktivieren

### Cloud Firestore
1. Firebase Console > Firestore Database > "Datenbank erstellen"
2. Standort: `europe-west3` (Frankfurt)
3. Sicherheitsregeln: "Produktionsmodus" waehlen
4. Dann `firestore.rules` aus diesem Projekt deployen:
   ```bash
   firebase deploy --only firestore:rules
   ```

### Cloud Messaging (Push)
1. Wird automatisch aktiviert mit dem Firebase-Projekt

## 4. Firebase CLI (optional)

```bash
npm install -g firebase-tools
firebase login
firebase init
firebase deploy --only firestore
```

## 5. FlutterFire CLI (Alternative)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=warteliste-pro
```

Dies erstellt automatisch `lib/firebase_options.dart`.

## 6. Erster Start

Nach dem Ablegen der `google-services.json`:
```bash
flutter run
```
