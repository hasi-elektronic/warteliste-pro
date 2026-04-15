import 'dart:io' show File, Directory;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'web_downloader_stub.dart'
    if (dart.library.html) 'web_downloader_web.dart' as downloader;

/// Service fuer den Export und das Teilen von Dateien.
///
/// Auf Mobile/Desktop wird die Datei im temporaeren Verzeichnis
/// gespeichert und ueber den System-Share-Dialog geteilt.
/// Auf Web wird ein Browser-Download ausgeloest.
class ExportService {
  static const String _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  ExportService();

  /// Speichert Excel-Bytes und teilt/downloadet sie je nach Plattform.
  ///
  /// [bytes] - Die rohen Datei-Bytes (z.B. von ExcelService.exportToExcel).
  /// [filename] - Der Dateiname inkl. Endung, z.B. 'warteliste_2024.xlsx'.
  ///
  /// Gibt auf Mobile/Desktop den Dateipfad zurueck, auf Web den Dateinamen.
  Future<String> shareExcel(List<int> bytes, String filename) async {
    if (kIsWeb) {
      downloader.downloadBytes(bytes, filename, _xlsxMime);
      return filename;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$filename';
    final file = File(filePath);

    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: filename,
    );

    return filePath;
  }

  /// Speichert Bytes als temporaere Datei ohne zu teilen.
  ///
  /// Auf Web wird der Browser-Download ausgeloest, da es kein
  /// temporaeres Dateisystem gibt.
  Future<String> saveToTemp(List<int> bytes, String filename) async {
    if (kIsWeb) {
      downloader.downloadBytes(bytes, filename, _xlsxMime);
      return filename;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$filename';
    final file = File(filePath);

    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  /// Raeumt temporaere Export-Dateien auf.
  ///
  /// Loescht alle .xlsx-Dateien im temporaeren Verzeichnis,
  /// die aelter als [maxAge] sind. Auf Web ein No-Op.
  Future<void> cleanupTempFiles({
    Duration maxAge = const Duration(days: 1),
  }) async {
    if (kIsWeb) return;

    final tempDir = await getTemporaryDirectory();
    final dir = Directory(tempDir.path);

    if (!await dir.exists()) return;

    final cutoff = DateTime.now().subtract(maxAge);

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.xlsx')) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    }
  }
}
