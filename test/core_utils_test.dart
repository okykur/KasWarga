import 'package:flutter_test/flutter_test.dart';
import 'package:kaswarga/core/constants/app_constants.dart';
import 'package:kaswarga/core/routing/role_route_guard.dart';
import 'package:kaswarga/core/utils/app_formatters.dart';
import 'package:kaswarga/core/utils/phone_number_formatter.dart';
import 'package:kaswarga/core/utils/validators.dart';

void main() {
  group('AppFormatters', () {
    test('memformat Rupiah tanpa desimal', () {
      expect(AppFormatters.rupiah(150000), 'Rp150.000');
    });

    test('memformat tanggal Indonesia', () {
      expect(AppFormatters.date(DateTime(2026, 6, 9)), '9 Juni 2026');
    });
  });

  group('BillStatus', () {
    test('memetakan status database ke label Indonesia', () {
      expect(BillStatus.fromValue('paid').label, 'Lunas');
      expect(
        BillStatus.fromValue('waiting_verification').label,
        'Menunggu Verifikasi',
      );
      expect(BillStatus.fromValue('unknown'), BillStatus.unpaid);
    });
  });

  group('Validators', () {
    test('nomor rekening wajib hanya angka', () {
      expect(Validators.accountNumber('1234567890'), isNull);
      expect(Validators.accountNumber('123-456'), isNotNull);
      expect(Validators.accountNumber(''), isNotNull);
    });
  });

  group('PhoneNumberFormatter', () {
    test('normalisasi format Indonesia ke +62', () {
      expect(
        PhoneNumberFormatter.normalizeIndonesianPhoneNumber('081234567890'),
        '+6281234567890',
      );
      expect(
        PhoneNumberFormatter.normalizeIndonesianPhoneNumber('6281234567890'),
        '+6281234567890',
      );
      expect(
        PhoneNumberFormatter.normalizeIndonesianPhoneNumber('+6281234567890'),
        '+6281234567890',
      );
    });

    test('validasi menolak spasi dan tanda hubung', () {
      expect(
        PhoneNumberFormatter.isValidIndonesianPhoneNumber('081234567890'),
        isTrue,
      );
      expect(
        PhoneNumberFormatter.isValidIndonesianPhoneNumber('0812-3456-7890'),
        isFalse,
      );
      expect(
        PhoneNumberFormatter.isValidIndonesianPhoneNumber('0812 3456 7890'),
        isFalse,
      );
    });

    test('deteksi identifier login', () {
      expect(
        PhoneNumberFormatter.detectLoginIdentifierType('warga@example.com'),
        LoginIdentifierType.email,
      );
      expect(
        PhoneNumberFormatter.detectLoginIdentifierType('081234567890'),
        LoginIdentifierType.phone,
      );
      expect(
        PhoneNumberFormatter.detectLoginIdentifierType('nama warga'),
        LoginIdentifierType.unknown,
      );
    });

    test('masking nomor handphone', () {
      expect(
        PhoneNumberFormatter.maskPhoneNumber('+6281234567890'),
        '+62812****7890',
      );
    });
  });

  group('Role route guard', () {
    test('member hanya boleh membuka area member', () {
      expect(
        isRouteAllowedForRole(UserRole.member, '/member/dashboard'),
        isTrue,
      );
      expect(
        isRouteAllowedForRole(UserRole.member, '/admin/dashboard'),
        isFalse,
      );
      expect(roleHomePath(UserRole.admin), '/admin/dashboard');
    });
  });
}
