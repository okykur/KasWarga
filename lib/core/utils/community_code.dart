class CommunityCode {
  const CommunityCode._();

  static String generate(String name, {int? year}) {
    final normalized = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final prefix = normalized.isEmpty ? 'KOMUNITAS' : normalized;
    final suffix = year ?? DateTime.now().year;
    final maxPrefix = 30 - suffix.toString().length - 1;
    return '${prefix.substring(0, prefix.length.clamp(0, maxPrefix))}-$suffix';
  }

  static String normalize(String value) => value.trim().toUpperCase();

  static bool isValid(String value) {
    final normalized = normalize(value);
    return RegExp(r'^[A-Z0-9-]{5,30}$').hasMatch(normalized);
  }

  static String? validationMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Kode komunitas wajib diisi.';
    }
    if (!isValid(value)) {
      return 'Gunakan 5-30 karakter: huruf besar, angka, atau tanda minus.';
    }
    return null;
  }
}
