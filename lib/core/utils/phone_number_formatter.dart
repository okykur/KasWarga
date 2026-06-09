enum LoginIdentifierType { email, phone, unknown }

class PhoneNumberFormatter {
  const PhoneNumberFormatter._();

  static String normalizeIndonesianPhoneNumber(String input) {
    final value = input.trim();
    if (!RegExp(r'^\+?\d+$').hasMatch(value)) {
      throw const FormatException('Nomor handphone tidak valid.');
    }

    if (value.startsWith('+62')) return value;
    if (value.startsWith('62')) return '+$value';
    if (value.startsWith('0')) return '+62${value.substring(1)}';
    throw const FormatException(
        'Nomor handphone harus diawali 08, 62, atau +62.');
  }

  static bool isValidIndonesianPhoneNumber(String input) {
    try {
      final normalized = normalizeIndonesianPhoneNumber(input);
      final digits = normalized.substring(1);
      return digits.startsWith('62') &&
          digits.length >= 10 &&
          digits.length <= 15;
    } on FormatException {
      return false;
    }
  }

  static String maskPhoneNumber(String input) {
    final normalized = normalizeIndonesianPhoneNumber(input);
    if (normalized.length <= 9) return normalized;
    return '${normalized.substring(0, 6)}****${normalized.substring(normalized.length - 4)}';
  }

  static LoginIdentifierType detectLoginIdentifierType(String input) {
    final value = input.trim();
    if (value.contains('@')) return LoginIdentifierType.email;
    if (RegExp(r'^\+?\d+$').hasMatch(value) &&
        (value.startsWith('08') ||
            value.startsWith('62') ||
            value.startsWith('+62'))) {
      return LoginIdentifierType.phone;
    }
    return LoginIdentifierType.unknown;
  }
}
