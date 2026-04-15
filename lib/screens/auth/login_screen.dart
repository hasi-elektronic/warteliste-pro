import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/patienten_provider.dart';
import '../../providers/standort_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';

/// Anmeldebildschirm mit E-Mail und Passwort.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.signIn(
        _emailController.text,
        _passwordController.text,
      );

      // Offene Einladungen einloesen
      await firebaseService.redeemInvites();

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

      String message = 'Anmeldung fehlgeschlagen.';
      final errorStr = e.toString();

      if (errorStr.contains('user-not-found')) {
        message = 'Kein Konto mit dieser E-Mail gefunden.';
      } else if (errorStr.contains('wrong-password')) {
        message = 'Falsches Passwort.';
      } else if (errorStr.contains('invalid-email')) {
        message = 'Ungueltige E-Mail-Adresse.';
      } else if (errorStr.contains('too-many-requests')) {
        message = 'Zu viele Versuche. Bitte spaeter erneut probieren.';
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
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // ── Logo-Bereich ──
                  Icon(
                    Icons.medical_services_outlined,
                    size: 52,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wartelisten-Verwaltung fuer Ihre Praxis',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                  const SizedBox(height: 32),

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
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // ── Anmelden-Button ──
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
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
                              'Anmelden',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Registrieren-Link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Noch kein Konto? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pushReplacementNamed('/register');
                        },
                        child: const Text('Registrieren'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
