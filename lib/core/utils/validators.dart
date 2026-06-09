import 'phone_number_formatter.dart';

class Validators {
  const Validators._();

  static String? required(String? value, {String field = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, field: 'Email');
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
      return 'Format email belum valid.';
    }
    return null;
  }

  static String? phone(String? value) {
    final requiredError = required(value, field: 'Nomor handphone');
    if (requiredError != null) return requiredError;
    if (!PhoneNumberFormatter.isValidIndonesianPhoneNumber(value!)) {
      return 'Gunakan nomor Indonesia yang valid tanpa spasi atau tanda hubung.';
    }
    return null;
  }

  static String? accountNumber(String? value) {
    final requiredError = required(value, field: 'Nomor rekening');
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^\d+$').hasMatch(value!)) {
      return 'Nomor rekening hanya boleh berisi angka.';
    }
    return null;
  }

  static String? positiveAmount(String? value) {
    final parsed = num.tryParse((value ?? '').replaceAll('.', ''));
    if (parsed == null || parsed <= 0) {
      return 'Nominal harus lebih dari 0.';
    }
    return null;
  }

  static String? password(String? value) {
    if ((value ?? '').length < 8) {
      return 'Password minimal 8 karakter.';
    }
    return null;
  }
}
