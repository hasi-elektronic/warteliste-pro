/// Stub-Implementierung fuer Nicht-Web-Plattformen.
///
/// Wird via Conditional Imports nur auf Mobile/Desktop verwendet.
/// Auf Web wird statt dessen [web_downloader_web.dart] geladen.
void downloadBytes(List<int> bytes, String filename, String mimeType) {
  // Auf Mobile/Desktop nicht erreichbar, da der Aufrufer kIsWeb prueft.
  throw UnsupportedError(
    'downloadBytes ist nur auf Web verfuegbar. '
    'Auf Mobile/Desktop wird Share.shareXFiles verwendet.',
  );
}
