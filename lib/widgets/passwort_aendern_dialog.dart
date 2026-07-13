import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/patienten_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';

/// Wiederverwendbarer "Passwort ändern"-Dialog (Dashboard-Warnung +
/// Einstellungen). Ändert das eigene Passwort und entfernt die
/// Sicherheits-Warnung (passwortAenderungEmpfohlen).
Future<void> showPasswortAendernDialog(
    BuildContext context, WidgetRef ref) async {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool obscure1 = true, obscure2 = true, busy = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        void snack(String m, {bool err = false}) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(m),
            backgroundColor: err ? AppTheme.errorColor : AppTheme.primaryColor,
          ));
        }

        return AlertDialog(
          title: const Text('Passwort ändern'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: obscure1,
                  decoration: InputDecoration(
                    labelText: 'Aktuelles Passwort',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscure1
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setLocal(() => obscure1 = !obscure1),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: obscure2,
                  decoration: InputDecoration(
                    labelText: 'Neues Passwort (mind. 8 Zeichen)',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(obscure2
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setLocal(() => obscure2 = !obscure2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscure2,
                  decoration: const InputDecoration(
                    labelText: 'Neues Passwort bestätigen',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Später'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final cur = currentCtrl.text;
                      final nw = newCtrl.text;
                      final cf = confirmCtrl.text;
                      if (cur.isEmpty || nw.isEmpty || cf.isEmpty) {
                        snack('Bitte alle Felder ausfüllen', err: true);
                        return;
                      }
                      if (nw.length < 8) {
                        snack('Neues Passwort min. 8 Zeichen', err: true);
                        return;
                      }
                      if (nw != cf) {
                        snack('Passwörter stimmen nicht überein', err: true);
                        return;
                      }
                      setLocal(() => busy = true);
                      try {
                        await ref
                            .read(firebaseServiceProvider)
                            .changePassword(
                                currentPassword: cur, newPassword: nw);
                        // Profil neu laden (Warnung verschwindet)
                        ref.read(appUserProvider.notifier).load();
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Passwort erfolgreich geändert')),
                          );
                        }
                      } catch (e) {
                        setLocal(() => busy = false);
                        final s = e.toString();
                        String msg = 'Fehler: $e';
                        if (s.contains('wrong-password') ||
                            s.contains('invalid-credential')) {
                          msg = 'Aktuelles Passwort ist falsch.';
                        } else if (s.contains('weak-password')) {
                          msg = 'Neues Passwort zu schwach.';
                        } else if (s.contains('requires-recent-login')) {
                          msg = 'Bitte erneut anmelden und nochmal versuchen.';
                        }
                        snack(msg, err: true);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Speichern'),
            ),
          ],
        );
      },
    ),
  );
}
