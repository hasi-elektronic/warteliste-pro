import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service fuer Firebase Cloud Messaging (Push-Benachrichtigungen).
///
/// Verantwortlich fuer:
/// - Berechtigungen anfragen
/// - FCM-Token abrufen und in Firestore speichern
/// - Foreground-Nachrichten empfangen
///
/// Die eigentliche Push-Logik (z.B. Benachrichtigung bei neuem Patienten)
/// wird serverseitig ueber Cloud Functions implementiert.
class NotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  /// Das aktuelle FCM-Token, nachdem [initialize] aufgerufen wurde.
  String? _token;
  String? get token => _token;

  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initialisiert den Benachrichtigungsservice.
  ///
  /// 1. Fragt beim Nutzer die Berechtigung an (iOS/Web).
  /// 2. Ruft das FCM-Token ab.
  /// 3. Registriert einen Listener fuer Token-Aktualisierungen.
  /// 4. Konfiguriert den Foreground-Nachrichten-Handler.
  ///
  /// Gibt `true` zurueck, wenn Berechtigungen erteilt wurden.
  Future<bool> initialize() async {
    // Berechtigung anfragen
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final authorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!authorized) return false;

    // Token abrufen
    _token = await _messaging.getToken();

    // Token-Refresh-Listener
    _messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
    });

    // Foreground-Nachrichten konfigurieren
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    return true;
  }

  /// Speichert das aktuelle FCM-Token in Firestore unter
  /// /praxen/{praxisId}/tokens/{token}.
  ///
  /// Das Token-Dokument enthaelt:
  /// - token: das FCM-Token
  /// - updatedAt: Zeitstempel der letzten Aktualisierung
  /// - platform: 'android', 'ios' oder 'web'
  Future<void> saveToken(String praxisId) async {
    if (_token == null) return;

    await _firestore
        .collection('praxen')
        .doc(praxisId)
        .collection('tokens')
        .doc(_token)
        .set({
      'token': _token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Entfernt das aktuelle Token aus Firestore (z.B. bei Logout).
  Future<void> removeToken(String praxisId) async {
    if (_token == null) return;

    await _firestore
        .collection('praxen')
        .doc(praxisId)
        .collection('tokens')
        .doc(_token)
        .delete();
  }

  /// Registriert einen Callback fuer eingehende Nachrichten im Vordergrund.
  void onForegroundMessage(void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  /// Registriert einen Callback fuer Nachrichten-Taps (App war im Hintergrund).
  void onMessageOpenedApp(void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  /// Prueft, ob die App durch eine Benachrichtigung geoeffnet wurde
  /// und gibt die Nachricht zurueck (oder null).
  Future<RemoteMessage?> getInitialMessage() async {
    return _messaging.getInitialMessage();
  }
}
