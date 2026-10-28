/// Local, UI-only form validation. Server-side validation is still required
/// once a backend exists.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? required(String? value, String field) =>
      (value == null || value.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email address is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required';
    if (v.length < 2) return 'Name is too short';
    return null;
  }

  /// Indian mobile number: 10 digits starting with 6-9 (spaces allowed).
  static String? indianPhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? loginPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Password is required' : null;

  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }
}

class PasswordStrength {
  PasswordStrength(String password)
      : hasLength = password.length >= 8,
        hasMixedCase = RegExp(r'[a-z]').hasMatch(password) &&
            RegExp(r'[A-Z]').hasMatch(password),
        hasNumberOrSymbol = RegExp(r'[0-9\W_]').hasMatch(password),
        isLong = password.length >= 12,
        isEmpty = password.isEmpty;

  final bool hasLength;
  final bool hasMixedCase;
  final bool hasNumberOrSymbol;
  final bool isLong;
  final bool isEmpty;

  /// 0..4
  int get score => isEmpty
      ? 0
      : [hasLength, hasMixedCase, hasNumberOrSymbol, isLong]
          .where((ok) => ok)
          .length;

  String get label => switch (score) {
        0 => isEmpty ? 'Not set' : 'Too weak',
        1 => 'Weak',
        2 => 'Fair',
        3 => 'Strong',
        _ => 'Very strong',
      };
}
