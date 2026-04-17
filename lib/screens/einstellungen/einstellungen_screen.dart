import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/strings.dart';
import '../../models/app_user.dart';
import '../../models/praxis.dart';
import '../../models/therapeut.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/patienten_provider.dart';
import '../../providers/standort_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/excel_service.dart';
import '../../services/export_service.dart';
import '../../utils/theme.dart';

/// Einstellungen-Screen mit Praxis-Profil, Therapeuten-Verwaltung,
/// Import/Export und Konto-Einstellungen.
class EinstellungenScreen extends ConsumerStatefulWidget {
  const EinstellungenScreen({super.key});

  @override
  ConsumerState<EinstellungenScreen> createState() =>
      _EinstellungenScreenState();
}

class _EinstellungenScreenState extends ConsumerState<EinstellungenScreen> {
  // Praxis-Felder
  final _praxisNameController = TextEditingController();
  final _inhaberController = TextEditingController();
  final _adresseController = TextEditingController();
  final _telefonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _praxisLoading = true;
  bool _praxisSaving = false;
  bool _importing = false;
  bool _exporting = false;
  bool _backingUp = false;
  bool _pushNotifications = true;

  Praxis? _praxis;
  List<Therapeut> _therapeuten = [];
  bool _therapeutenLoading = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPraxis();
      _loadTherapeuten();
      _loadVersion();
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {
      // ignore
    }
  }

  /// Liefert die Praxis-ID des aktuellen Nutzers.
  ///
  /// Faellt bei Bedarf auf [FirebaseService.currentPraxisId] zurueck,
  /// falls der [praxisIdProvider] noch nicht gesetzt wurde
  /// (Race-Condition zwischen async App-Init und UI-Aufbau).
  /// Aktualisiert dabei den Provider, damit andere Widgets nachziehen.
  Future<String?> _resolvePraxisId() async {
    final fromProvider = ref.read(praxisIdProvider);
    if (fromProvider != null && fromProvider.isNotEmpty) {
      return fromProvider;
    }
    final service = ref.read(firebaseServiceProvider);
    final praxisId = await service.currentPraxisId;
    if (praxisId != null && praxisId.isNotEmpty && mounted) {
      ref.read(praxisIdProvider.notifier).state = praxisId;
    }
    return praxisId;
  }

  @override
  void dispose() {
    _praxisNameController.dispose();
    _inhaberController.dispose();
    _adresseController.dispose();
    _telefonController.dispose();
    super.dispose();
  }

  Future<void> _loadPraxis() async {
    final service = ref.read(firebaseServiceProvider);
    final praxisId = await _resolvePraxisId();
    if (praxisId == null) {
      if (mounted) setState(() => _praxisLoading = false);
      return;
    }

    try {
      final praxis = await service.getPraxis(praxisId);
      if (praxis != null && mounted) {
        setState(() {
          _praxis = praxis;
          _praxisNameController.text = praxis.name;
          _inhaberController.text = praxis.inhaber;
          _adresseController.text = praxis.adresse;
          _telefonController.text = praxis.telefon;
          _praxisLoading = false;
        });
      } else {
        setState(() => _praxisLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _praxisLoading = false);
        _showSnackBar('Fehler beim Laden der Praxis-Daten', isError: true);
      }
    }
  }

  Future<void> _loadTherapeuten() async {
    final service = ref.read(firebaseServiceProvider);
    final praxisId = await _resolvePraxisId();
    if (praxisId == null) {
      if (mounted) setState(() => _therapeutenLoading = false);
      return;
    }

    service.getTherapeuten(praxisId).listen(
      (therapeuten) {
        if (mounted) {
          setState(() {
            _therapeuten = therapeuten;
            _therapeutenLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _therapeutenLoading = false);
        }
      },
    );
  }

  Future<void> _savePraxis() async {
    if (!_formKey.currentState!.validate()) return;
    if (_praxis == null) return;

    setState(() => _praxisSaving = true);

    try {
      final updated = _praxis!.copyWith(
        name: _praxisNameController.text.trim(),
        inhaber: _inhaberController.text.trim(),
        adresse: _adresseController.text.trim(),
        telefon: _telefonController.text.trim(),
      );
      await ref.read(firebaseServiceProvider).updatePraxis(updated);
      if (mounted) {
        setState(() {
          _praxis = updated;
          _praxisSaving = false;
        });
        // Standort-Liste aktualisieren damit der Name im Switcher stimmt
        ref.read(standorteProvider.notifier).load();
        _showSnackBar('Praxis-Daten gespeichert');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _praxisSaving = false);
        _showSnackBar('Fehler beim Speichern', isError: true);
      }
    }
  }

  Future<void> _addTherapeut() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Therapeut hinzufuegen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Vor- und Nachname',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Hinzufuegen'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.trim().isEmpty) return;

    final praxisId = await _resolvePraxisId();
    if (praxisId == null) {
      _showSnackBar('Keine Praxis gefunden. Bitte neu anmelden.',
          isError: true);
      return;
    }

    try {
      final therapeut = Therapeut(
        id: '',
        name: name.trim(),
        aktiv: true,
        praxisId: praxisId,
      );
      await ref.read(firebaseServiceProvider).addTherapeut(therapeut);
      _showSnackBar('Therapeut hinzugefuegt');
      // Liste neu laden, falls Stream noch nicht aktiv ist.
      if (_therapeutenLoading) {
        await _loadTherapeuten();
      }
    } catch (e) {
      _showSnackBar('Fehler beim Hinzufuegen: $e', isError: true);
    }
  }

  Future<void> _toggleTherapeut(Therapeut therapeut) async {
    try {
      final updated = therapeut.copyWith(aktiv: !therapeut.aktiv);
      await ref.read(firebaseServiceProvider).updateTherapeut(updated);
    } catch (e) {
      _showSnackBar('Fehler beim Aktualisieren', isError: true);
    }
  }

  Future<void> _deleteTherapeut(Therapeut therapeut) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Therapeut loeschen?'),
        content: Text(
          '${therapeut.name} wirklich loeschen? '
          'Diese Aktion kann nicht rueckgaengig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Loeschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(firebaseServiceProvider)
          .deleteTherapeut(therapeut.praxisId, therapeut.id);
      _showSnackBar('Therapeut geloescht');
    } catch (e) {
      _showSnackBar('Fehler beim Loeschen', isError: true);
    }
  }

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.single.path == null) return;

    final praxisId = await _resolvePraxisId();
    if (praxisId == null) {
      _showSnackBar('Keine Praxis gefunden. Bitte neu anmelden.',
          isError: true);
      return;
    }

    setState(() => _importing = true);

    try {
      final filePath = result.files.single.path!;
      final excelService = ExcelService();
      final patienten = await excelService.importFromExcel(filePath, praxisId);

      final service = ref.read(firebaseServiceProvider);
      int imported = 0;
      for (final patient in patienten) {
        await service.addPatient(patient);
        imported++;
      }

      if (mounted) {
        setState(() => _importing = false);
        _showSnackBar('$imported Patienten importiert');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        _showSnackBar('Import fehlgeschlagen: $e', isError: true);
      }
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);

    try {
      // Praxis-ID sicherstellen, damit der StreamProvider Daten hat.
      final praxisId = await _resolvePraxisId();
      if (praxisId == null) {
        setState(() => _exporting = false);
        _showSnackBar('Keine Praxis gefunden. Bitte neu anmelden.',
            isError: true);
        return;
      }

      // Patienten direkt laden, falls der Stream noch nichts geliefert hat.
      var patienten = ref.read(patientenProvider).valueOrNull;
      if (patienten == null || patienten.isEmpty) {
        final stream = ref
            .read(firebaseServiceProvider)
            .getPatienten(praxisId);
        patienten = await stream.first;
      }

      if (patienten.isEmpty) {
        setState(() => _exporting = false);
        _showSnackBar('Keine Patienten zum Exportieren vorhanden');
        return;
      }

      final excelService = ExcelService();
      final bytes = await excelService.exportToExcel(patienten);

      final exportService = ExportService();
      final filename =
          'warteliste_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}.xlsx';
      await exportService.shareExcel(bytes, filename);

      if (mounted) {
        setState(() => _exporting = false);
        _showSnackBar('Export erstellt');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        _showSnackBar('Export fehlgeschlagen: $e', isError: true);
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden?'),
        content: const Text('Moechten Sie sich wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(firebaseServiceProvider).signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Fehler beim Abmelden', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(firebaseServiceProvider);
    final email = service.currentUser?.email ?? '';
    final isAdmin = ref.watch(isAdminProvider);
    final s = S.of(context);

    // Keine eigene AppBar — wird vom DashboardScreen (AppHeader) gestellt.
    return Scaffold(
      body: _praxisLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // ── Praxis-Profil ──
                _buildSectionHeader(
                    s.sektionPraxisProfil, Icons.business_rounded),
                _buildPraxisCard(s),

                const SizedBox(height: 8),

                // ── Standorte (nur Admin) ──
                if (isAdmin) ...[
                  _buildSectionHeader(
                    s.isGerman ? 'Standorte' : 'Locations',
                    Icons.location_city_rounded,
                  ),
                  _buildStandorteCard(s),
                  const SizedBox(height: 8),
                ],

                // ── Mitarbeiter (nur Admin) ──
                if (isAdmin) ...[
                  _buildSectionHeader(
                    s.isGerman ? 'Mitarbeiter' : 'Team members',
                    Icons.group_rounded,
                  ),
                  _buildMitarbeiterCard(s),
                  const SizedBox(height: 8),
                ],

                // ── Therapeuten ──
                _buildSectionHeader(
                  s.sektionTherapeuten,
                  Icons.people_rounded,
                ),
                _buildTherapeutenCard(s),

                const SizedBox(height: 8),

                // ── Daten ──
                _buildSectionHeader(
                  s.sektionDaten,
                  Icons.folder_rounded,
                ),
                _buildDatenCard(s),

                const SizedBox(height: 8),

                // ── Benachrichtigungen ──
                _buildSectionHeader(
                  s.sektionBenachrichtigungen,
                  Icons.notifications_rounded,
                ),
                _buildBenachrichtigungenCard(s),

                const SizedBox(height: 8),

                // ── Design (Dark Mode) ──
                _buildSectionHeader(
                  s.isGerman ? 'Design' : 'Appearance',
                  Icons.palette_rounded,
                ),
                _buildDesignCard(s),

                const SizedBox(height: 8),

                // ── Sprache ──
                _buildSectionHeader(
                  s.sektionSprache,
                  Icons.language_rounded,
                ),
                _buildSpracheCard(s),

                const SizedBox(height: 8),

                // ── Konto ──
                _buildSectionHeader(
                    s.sektionKonto, Icons.account_circle_rounded),
                _buildKontoCard(email, s, isAdmin),

                const SizedBox(height: 8),

                // ── About ──
                _buildSectionHeader(
                  s.sektionAbout,
                  Icons.info_outline_rounded,
                ),
                _buildAboutCard(s),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────────
  // Standorte Card
  // ──────────────────────────────────────────────

  Widget _buildStandorteCard(S s) {
    final standorteAsync = ref.watch(standorteProvider);
    final currentPraxisId = ref.watch(praxisIdProvider);
    final isGerman = s.isGerman;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: standorteAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text(
            isGerman
                ? 'Fehler beim Laden der Standorte'
                : 'Error loading locations',
            style: TextStyle(color: AppTheme.errorColor),
          ),
          data: (standorte) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (standorte.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    isGerman
                        ? 'Keine Standorte vorhanden'
                        : 'No locations found',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ...standorte.map((praxis) {
                final isActive = praxis.id == currentPraxisId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? AppTheme.primaryColor
                        : Colors.grey.shade200,
                    radius: 18,
                    child: Icon(
                      Icons.business,
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    praxis.name,
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: praxis.adresse.isNotEmpty
                      ? Text(
                          praxis.adresse,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isGerman ? 'Aktiv' : 'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      if (!isActive && standorte.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () =>
                              _confirmRemoveStandort(praxis, isGerman),
                          tooltip:
                              isGerman ? 'Entfernen' : 'Remove',
                        ),
                    ],
                  ),
                  onTap: isActive
                      ? null
                      : () async {
                          final service =
                              ref.read(firebaseServiceProvider);
                          await service.switchStandort(praxis.id);
                          if (mounted) {
                            ref.read(praxisIdProvider.notifier).state =
                                praxis.id;
                            _loadPraxis();
                            _loadTherapeuten();
                            _showSnackBar(
                              isGerman
                                  ? 'Standort gewechselt: ${praxis.name}'
                                  : 'Location switched: ${praxis.name}',
                            );
                          }
                        },
                );
              }),
              const Divider(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddStandortDialog(isGerman),
                  icon: const Icon(Icons.add),
                  label: Text(
                    isGerman
                        ? 'Neuen Standort hinzufuegen'
                        : 'Add new location',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStandortDialog(bool isGerman) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isGerman ? 'Neuer Standort' : 'New location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isGerman ? 'Standort-Name' : 'Location name',
            hintText: isGerman
                ? 'z.B. Filiale Muenchen'
                : 'e.g. Branch Munich',
            prefixIcon: const Icon(Icons.business),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isGerman ? 'Abbrechen' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();

              final notifier = ref.read(standorteProvider.notifier);
              final praxis = await notifier.addStandort(name);

              // Zum neuen Standort wechseln
              final service = ref.read(firebaseServiceProvider);
              await service.switchStandort(praxis.id);
              if (mounted) {
                ref.read(praxisIdProvider.notifier).state = praxis.id;
                _loadPraxis();
                _loadTherapeuten();
                _showSnackBar(
                  isGerman
                      ? 'Standort "$name" erstellt'
                      : 'Location "$name" created',
                );
              }
            },
            child: Text(isGerman ? 'Erstellen' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveStandort(Praxis praxis, bool isGerman) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isGerman
              ? 'Standort entfernen?'
              : 'Remove location?',
        ),
        content: Text(
          isGerman
              ? '"${praxis.name}" wird aus Ihrer Standort-Liste entfernt. '
                'Die Daten bleiben erhalten.'
              : '"${praxis.name}" will be removed from your locations. '
                'Data will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isGerman ? 'Abbrechen' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final notifier = ref.read(standorteProvider.notifier);
              await notifier.removeStandort(praxis.id);
              if (mounted) {
                _loadPraxis();
                _loadTherapeuten();
                _showSnackBar(
                  isGerman
                      ? 'Standort entfernt'
                      : 'Location removed',
                );
              }
            },
            child: Text(isGerman ? 'Entfernen' : 'Remove'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Design Card (Dark Mode)
  // ──────────────────────────────────────────────

  Widget _buildDesignCard(S s) {
    final currentMode = ref.watch(themeModeProvider);
    final isGerman = s.isGerman;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          RadioListTile<ThemeMode>(
            title: Text(isGerman ? 'System' : 'System'),
            subtitle: Text(
              isGerman
                  ? 'Automatisch nach Geraeteeinstellung'
                  : 'Follow device setting',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            value: ThemeMode.system,
            groupValue: currentMode,
            activeColor: AppTheme.primaryColor,
            secondary: const Icon(Icons.brightness_auto),
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(isGerman ? 'Hell' : 'Light'),
            value: ThemeMode.light,
            groupValue: currentMode,
            activeColor: AppTheme.primaryColor,
            secondary: const Icon(Icons.light_mode),
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(isGerman ? 'Dunkel' : 'Dark'),
            value: ThemeMode.dark,
            groupValue: currentMode,
            activeColor: AppTheme.primaryColor,
            secondary: const Icon(Icons.dark_mode),
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Sprache Card
  // ──────────────────────────────────────────────

  Widget _buildSpracheCard(S s) {
    final currentLocale = ref.watch(localeProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          RadioListTile<String>(
            title: Text(s.languageGerman),
            value: 'de',
            groupValue: currentLocale.languageCode,
            activeColor: AppTheme.primaryColor,
            secondary: const Text('🇩🇪', style: TextStyle(fontSize: 24)),
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(localeProvider.notifier)
                    .setLocale(Locale(value));
              }
            },
          ),
          RadioListTile<String>(
            title: Text(s.languageEnglish),
            value: 'en',
            groupValue: currentLocale.languageCode,
            activeColor: AppTheme.primaryColor,
            secondary: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(localeProvider.notifier)
                    .setLocale(Locale(value));
              }
            },
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // About Card
  // ──────────────────────────────────────────────

  Widget _buildAboutCard(S s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // App Icon / Logo
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.medical_services_rounded,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              s.aboutBeschreibung,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildAboutRow(
              Icons.tag_rounded,
              s.aboutVersion,
              _appVersion.isEmpty ? '...' : _appVersion,
            ),
            const SizedBox(height: 12),
            _buildAboutRow(
              Icons.code_rounded,
              s.aboutEntwicktVon,
              s.aboutDeveloperName,
            ),
            const SizedBox(height: 16),
            Text(
              s.aboutCopyright,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Section Header
  // ──────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Praxis-Profil Card
  // ──────────────────────────────────────────────

  Widget _buildPraxisCard(S s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _praxisNameController,
                decoration: InputDecoration(
                  labelText: s.praxisName,
                  prefixIcon: const Icon(Icons.local_hospital_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return s.isGerman
                        ? 'Bitte Praxis-Name eingeben'
                        : 'Please enter practice name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _inhaberController,
                decoration: InputDecoration(
                  labelText: s.praxisInhaber,
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adresseController,
                decoration: InputDecoration(
                  labelText: s.praxisAdresse,
                  prefixIcon: const Icon(Icons.location_on_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonController,
                decoration: InputDecoration(
                  labelText: s.praxisTelefon,
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _praxisSaving ? null : _savePraxis,
                  icon: _praxisSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(s.speichern),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Therapeuten Card
  // ──────────────────────────────────────────────

  Widget _buildTherapeutenCard(S s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_therapeutenLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_therapeuten.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  s.therapeutKeine,
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              )
            else
              ..._therapeuten.map((t) => _buildTherapeutTile(t, s)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addTherapeut,
                icon: const Icon(Icons.person_add_rounded),
                label: Text(s.therapeutHinzufuegen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapeutTile(Therapeut therapeut, S s) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: therapeut.aktiv
            ? AppTheme.primaryColor.withValues(alpha: 0.15)
            : Colors.grey.shade200,
        child: Icon(
          Icons.person_rounded,
          color: therapeut.aktiv ? AppTheme.primaryColor : Colors.grey,
        ),
      ),
      title: Text(
        therapeut.name,
        style: TextStyle(
          decoration:
              therapeut.aktiv ? null : TextDecoration.lineThrough,
          color: therapeut.aktiv ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        therapeut.aktiv ? s.aktiv : s.inaktiv,
        style: TextStyle(
          fontSize: 12,
          color: therapeut.aktiv
              ? AppTheme.successColor
              : Colors.grey.shade500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: therapeut.aktiv,
            activeColor: AppTheme.primaryColor,
            onChanged: (_) => _toggleTherapeut(therapeut),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.errorColor,
            ),
            onPressed: () => _deleteTherapeut(therapeut),
            tooltip: s.loeschen,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Daten Card (Import/Export)
  // ──────────────────────────────────────────────

  Future<void> _createBackup() async {
    final s = S.of(context);
    setState(() => _backingUp = true);

    try {
      final praxisId = await _resolvePraxisId();
      if (praxisId == null) {
        setState(() => _backingUp = false);
        _showSnackBar(s.isGerman
            ? 'Keine Praxis gefunden'
            : 'No practice found', isError: true);
        return;
      }

      // Alle Patienten laden
      var patienten = ref.read(patientenProvider).valueOrNull;
      if (patienten == null || patienten.isEmpty) {
        final stream = ref.read(firebaseServiceProvider).getPatienten(praxisId);
        patienten = await stream.first;
      }

      if (patienten.isEmpty) {
        setState(() => _backingUp = false);
        _showSnackBar(s.isGerman
            ? 'Keine Daten zum Sichern'
            : 'No data to backup');
        return;
      }

      final excelService = ExcelService();
      final bytes = await excelService.exportToExcel(patienten);

      final now = DateTime.now();
      final filename =
          'backup_warteliste_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.xlsx';

      final exportService = ExportService();
      await exportService.shareExcel(bytes, filename);

      if (mounted) {
        setState(() => _backingUp = false);
        _showSnackBar(s.isGerman
            ? 'Backup erstellt: ${patienten.length} Patienten gesichert'
            : 'Backup created: ${patienten.length} patients saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _backingUp = false);
        _showSnackBar('Backup fehlgeschlagen: $e', isError: true);
      }
    }
  }

  Widget _buildDatenCard(S s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Backup
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _backingUp ? null : _createBackup,
                icon: _backingUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.backup_rounded),
                label: Text(_backingUp
                    ? (s.isGerman ? 'Backup wird erstellt...' : 'Creating backup...')
                    : (s.isGerman ? 'Backup erstellen' : 'Create backup')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.isGerman
                  ? 'Alle Patientendaten als Excel-Datei sichern'
                  : 'Save all patient data as Excel file',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),

            // Import
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _importing ? null : _importExcel,
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(_importing
                    ? (s.isGerman ? 'Importiere...' : 'Importing...')
                    : s.excelImportieren),
              ),
            ),
            const SizedBox(height: 12),

            // Export
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _exporting ? null : _exportExcel,
                icon: _exporting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_exporting
                    ? (s.isGerman ? 'Exportiere...' : 'Exporting...')
                    : s.excelExportieren),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Benachrichtigungen Card
  // ──────────────────────────────────────────────

  Widget _buildBenachrichtigungenCard(S s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SwitchListTile(
        title: Text(s.pushBenachrichtigungen),
        subtitle: Text(
          s.pushBeschreibung,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        secondary: Icon(
          _pushNotifications
              ? Icons.notifications_active_rounded
              : Icons.notifications_off_rounded,
          color: _pushNotifications ? AppTheme.primaryColor : Colors.grey,
        ),
        value: _pushNotifications,
        activeColor: AppTheme.primaryColor,
        onChanged: (value) {
          setState(() => _pushNotifications = value);
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Konto Card
  // ──────────────────────────────────────────────

  Widget _buildKontoCard(String email, S s, bool isAdmin) {
    final isGerman = s.isGerman;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.email_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(s.email),
              subtitle: Text(
                email.isNotEmpty
                    ? email
                    : (isGerman ? 'Nicht angemeldet' : 'Not signed in'),
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? AppTheme.primaryColor.withValues(alpha: 0.12)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAdmin
                      ? (isGerman ? 'Admin' : 'Admin')
                      : (isGerman ? 'Mitarbeiter' : 'Staff'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAdmin
                        ? AppTheme.primaryColor
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: Text(s.abmelden),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Mitarbeiter Card (nur Admin)
  // ──────────────────────────────────────────────

  Widget _buildMitarbeiterCard(S s) {
    final praxisId = ref.watch(praxisIdProvider);
    final isGerman = s.isGerman;

    if (praxisId == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            isGerman ? 'Kein Standort ausgewaehlt' : 'No location selected',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<AppUser>>(
          future: ref.read(firebaseServiceProvider).getMitarbeiter(praxisId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final mitarbeiter = snapshot.data ?? [];
            final currentUid =
                ref.read(firebaseServiceProvider).currentUser?.uid;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mitarbeiter.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      isGerman
                          ? 'Keine Mitarbeiter in diesem Standort'
                          : 'No team members at this location',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ...mitarbeiter.map((user) {
                  final isSelf = user.uid == currentUid;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: user.isAdmin
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : AppTheme.accentColor.withValues(alpha: 0.15),
                      radius: 18,
                      child: Icon(
                        user.isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.person,
                        color: user.isAdmin
                            ? AppTheme.primaryColor
                            : AppTheme.accentColor,
                        size: 18,
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.email,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              isGerman ? '(Du)' : '(You)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      user.isAdmin
                          ? 'Admin'
                          : (isGerman ? 'Mitarbeiter' : 'Staff'),
                      style: TextStyle(
                        fontSize: 12,
                        color: user.isAdmin
                            ? AppTheme.primaryColor
                            : Colors.grey.shade600,
                      ),
                    ),
                    trailing: isSelf
                        ? null
                        : PopupMenuButton<String>(
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'role',
                                child: Row(
                                  children: [
                                    Icon(
                                      user.isAdmin
                                          ? Icons.person
                                          : Icons.admin_panel_settings,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      user.isAdmin
                                          ? (isGerman
                                              ? 'Zu Mitarbeiter machen'
                                              : 'Make staff')
                                          : (isGerman
                                              ? 'Zu Admin machen'
                                              : 'Make admin'),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_remove,
                                      size: 18,
                                      color: AppTheme.errorColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isGerman ? 'Entfernen' : 'Remove',
                                      style: TextStyle(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'role') {
                                final newRole = user.isAdmin
                                    ? UserRole.user
                                    : UserRole.admin;
                                await ref
                                    .read(firebaseServiceProvider)
                                    .updateUserRole(user.uid, newRole);
                                if (mounted) setState(() {});
                                _showSnackBar(
                                  isGerman
                                      ? 'Rolle geaendert'
                                      : 'Role changed',
                                );
                              } else if (value == 'remove') {
                                _confirmRemoveMitarbeiter(
                                  user,
                                  praxisId,
                                  isGerman,
                                );
                              }
                            },
                          ),
                  );
                }),
                const Divider(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showInviteMitarbeiterDialog(
                      praxisId,
                      isGerman,
                    ),
                    icon: const Icon(Icons.person_add),
                    label: Text(
                      isGerman
                          ? 'Mitarbeiter einladen'
                          : 'Invite team member',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showInviteMitarbeiterDialog(String praxisId, bool isGerman) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isGerman ? 'Mitarbeiter einladen' : 'Invite team member',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGerman
                  ? 'Geben Sie die E-Mail-Adresse des Mitarbeiters ein. '
                    'Falls bereits registriert, wird der Standort '
                    'automatisch freigeschaltet.'
                  : 'Enter the team member\'s email. '
                    'If already registered, they will get '
                    'automatic access to this location.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-Mail',
                hintText: 'mitarbeiter@praxis.de',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isGerman ? 'Abbrechen' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isEmpty || !email.contains('@')) return;
              Navigator.of(ctx).pop();

              try {
                final found = await ref
                    .read(firebaseServiceProvider)
                    .inviteMitarbeiter(email, praxisId);

                if (mounted) {
                  setState(() {}); // Liste neu bauen
                  _showSnackBar(
                    found
                        ? (isGerman
                            ? '$email wurde hinzugefuegt'
                            : '$email has been added')
                        : (isGerman
                            ? 'Einladung fuer $email gespeichert. '
                              'Wird bei der Registrierung eingeloest.'
                            : 'Invite saved for $email. '
                              'Will be redeemed on registration.'),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showSnackBar(
                    isGerman
                        ? 'Fehler beim Einladen: $e'
                        : 'Error inviting: $e',
                    isError: true,
                  );
                }
              }
            },
            child: Text(isGerman ? 'Einladen' : 'Invite'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMitarbeiter(
    AppUser user,
    String praxisId,
    bool isGerman,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isGerman ? 'Mitarbeiter entfernen?' : 'Remove team member?',
        ),
        content: Text(
          isGerman
              ? '"${user.email}" wird von diesem Standort entfernt.'
              : '"${user.email}" will be removed from this location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isGerman ? 'Abbrechen' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(firebaseServiceProvider)
                  .removeMitarbeiter(user.uid, praxisId);
              if (mounted) {
                setState(() {});
                _showSnackBar(
                  isGerman
                      ? 'Mitarbeiter entfernt'
                      : 'Team member removed',
                );
              }
            },
            child: Text(isGerman ? 'Entfernen' : 'Remove'),
          ),
        ],
      ),
    );
  }
}
