import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/patienten_provider.dart';
import '../../providers/standort_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';

/// Registrierungsbildschirm fuer neue Praxen.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _praxisNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _praxisNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.signUp(
        _emailController.text,
        _passwordController.text,
        _praxisNameController.text,
      );

      // PraxisId laden und im Provider setzen
      final praxisId = await firebaseService.currentPraxisId;
      if (!mounted) return;
      if (praxisId != null) {
        ref.read(praxisIdProvider.notifier).state = praxisId;
      }
      // User-Profil und Standorte laden
      ref.read(appUserProvider.notifier).load();
      ref.read(standorteProvider.notifier).load();

      Navigator.of(context).pushReplacementNamed('/');
    } on Exception catch (e) {
      if (!mounted) return;

      String message = 'Registrierung fehlgeschlagen.';
      final errorStr = e.toString();

      if (errorStr.contains('email-already-in-use')) {
        message = 'Diese E-Mail wird bereits verwendet.';
      } else if (errorStr.contains('weak-password')) {
        message = 'Das Passwort ist zu schwach. Mindestens 6 Zeichen.';
      } else if (errorStr.contains('invalid-email')) {
        message = 'Ungueltige E-Mail-Adresse.';
      } else if (errorStr.contains('network-request-failed')) {
        message = 'Keine Internetverbindung.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // ── Logo-Bereich ──
                  Icon(
                    Icons.medical_services_outlined,
                    size: 72,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Neues Konto erstellen',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // ── Praxis-Name ──
                  TextFormField(
                    controller: _praxisNameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Praxis-Name',
                      prefixIcon: Icon(Icons.business_outlined),
                      hintText: 'z.B. Logopaedie Musterstadt',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte Praxis-Name eingeben.';
                      }
                      if (value.trim().length < 3) {
                        return 'Mindestens 3 Zeichen.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── E-Mail ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-Mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte E-Mail eingeben.';
                      }
                      if (!value.contains('@')) {
                        return 'Bitte gueltige E-Mail eingeben.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Passwort ──
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte Passwort eingeben.';
                      }
                      if (value.length < 6) {
                        return 'Mindestens 6 Zeichen.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Passwort bestaetigen ──
                  TextFormField(
                    controller: _passwordConfirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleRegister(),
                    decoration: InputDecoration(
                      labelText: 'Passwort bestaetigen',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirm = !_obscureConfirm;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte Passwort bestaetigen.';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwoerter stimmen nicht ueberein.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // ── Registrieren-Button ──
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Registrieren',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Anmelden-Link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bereits ein Konto? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pushReplacementNamed('/login');
                        },
                        child: const Text('Anmelden'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
