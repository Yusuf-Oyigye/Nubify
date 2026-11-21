//===================================================
// EGYPTIAN MOBILE NUMBER VALIDATION
//===================================================

abstract final class EgyptianPhone {
  static final RegExp _localPattern = RegExp(r'^01[0125]\d{8}$');
  static final RegExp _internationalPattern = RegExp(r'^\+201[0125]\d{8}$');
  static final RegExp _nationalPattern = RegExp(r'^1[0125]\d{8}$');

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String? normalize(String value) {
    final String clean = value.trim().replaceAll(RegExp(r'[\s()-]'), '');

    if (_internationalPattern.hasMatch(clean)) {
      return clean;
    }

    final String digits = digitsOnly(clean);

    if (_localPattern.hasMatch(digits)) {
      return '+20${digits.substring(1)}';
    }

    if (_nationalPattern.hasMatch(digits)) {
      return '+20$digits';
    }

    if (digits.startsWith('20')) {
      final String withPlus = '+$digits';
      if (_internationalPattern.hasMatch(withPlus)) {
        return withPlus;
      }
    }

    return null;
  }

  static bool isValid(String value) => normalize(value) != null;

  static String displayLocal(String? e164) {
    final String clean = e164?.trim() ?? '';
    if (!_internationalPattern.hasMatch(clean)) {
      return '';
    }
    return '0${clean.substring(3)}';
  }

  static String? validationMessage(String value) {
    if (value.trim().isEmpty) {
      return 'Enter your Egyptian mobile number.';
    }
    if (!isValid(value)) {
      return 'Use 010, 011, 012 or 015 followed by 8 digits.';
    }
    return null;
  }
}
