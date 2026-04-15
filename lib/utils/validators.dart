/// Formular-Validatoren fuer deutsche Eingabefelder.
class Validators {
  Validators._();

  /// Pflichtfeld - darf nicht leer sein.
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pflichtfeld';
    }
    return null;
  }

  /// Pflichtfeld mit benutzerdefiniertem Feldnamen.
  static String? requiredWithName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName ist ein Pflichtfeld';
    }
    return null;
  }

  /// Telefonnummer-Validierung.
  ///
  /// Akzeptiert deutsche Formate:
  /// - 07041/123456
  /// - 07041 123456
  /// - +49 7041 123456
  /// - 0170-1234567
  /// - (07041) 123456
  static String? telefon(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Nicht erforderlich, nutze [required] zusaetzlich
    }

    final cleaned = value.replaceAll(RegExp(r'[\s\-\/\(\)\.]'), '');

    // Muss mindestens 6 Ziffern enthalten (ggf. mit + Prefix)
    final digitPattern = RegExp(r'^\+?\d{6,15}$');
    if (!digitPattern.hasMatch(cleaned)) {
      return 'Bitte eine gueltige Telefonnummer eingeben';
    }

    return null;
  }

  /// E-Mail-Validierung.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Nicht erforderlich, nutze [required] zusaetzlich
    }

    final emailPattern = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
    );

    if (!emailPattern.hasMatch(value.trim())) {
      return 'Bitte eine gueltige E-Mail-Adresse eingeben';
    }

    return null;
  }

  /// Kombiniert mehrere Validatoren. Der erste Fehler wird zurueckgegeben.
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }

  /// Mindestlaenge-Validierung.
  static String? Function(String?) minLength(int length) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) return null;
      if (value.trim().length < length) {
        return 'Mindestens $length Zeichen erforderlich';
      }
      return null;
    };
  }

  /// Maximallaenge-Validierung.
  static String? Function(String?) maxLength(int length) {
    return (String? value) {
      if (value == null) return null;
      if (value.length > length) {
        return 'Maximal $length Zeichen erlaubt';
      }
      return null;
    };
  }
}
