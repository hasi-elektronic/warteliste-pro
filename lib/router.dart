import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/bericht.dart';
import 'models/patient.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/bericht/bericht_form_screen.dart';
import 'screens/bericht/berichte_liste_screen.dart';
import 'screens/bericht/verordnungsbericht_form_screen.dart';
import 'screens/bericht/vordruck_liste_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/patient/patient_form_screen.dart';
import 'screens/warteliste/patient_detail_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        );
      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
      case '/register':
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
        );
      case '/patient/neu':
        return MaterialPageRoute(
          builder: (_) => const PatientFormScreen(),
        );
      case '/patient/bearbeiten':
        final patient = settings.arguments as Patient?;
        return MaterialPageRoute(
          builder: (_) => PatientFormScreen(patient: patient),
        );
      case '/patient/detail':
        final patient = settings.arguments as Patient;
        return MaterialPageRoute(
          builder: (_) => PatientDetailScreen(patient: patient),
        );
      case '/berichte':
        return MaterialPageRoute(
          builder: (_) => const BerichteListeScreen(),
        );
      case '/bericht/neu':
        final args = (settings.arguments as BerichtFormArgs?) ??
            const BerichtFormArgs();
        return MaterialPageRoute(
          builder: (_) => BerichtFormScreen(args: args),
        );
      case '/bericht/bearbeiten':
        final args = settings.arguments as BerichtFormArgs;
        return MaterialPageRoute(
          builder: (_) => BerichtFormScreen(args: args),
        );
      case '/vordrucke':
        return MaterialPageRoute(
          builder: (_) => const VordruckListeScreen(),
        );
      case '/verordnungsbericht/neu':
        final patient = settings.arguments as Patient?;
        return MaterialPageRoute(
          builder: (_) =>
              VerordnungsberichtFormScreen(patient: patient),
        );
      case '/verordnungsbericht/bearbeiten':
        final bericht = settings.arguments as Bericht;
        return MaterialPageRoute(
          builder: (_) => VerordnungsberichtFormScreen(
              berichtToEdit: bericht),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route nicht gefunden: ${settings.name}'),
            ),
          ),
        );
    }
  }

  static String get initialRoute {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? '/' : '/login';
  }
}
