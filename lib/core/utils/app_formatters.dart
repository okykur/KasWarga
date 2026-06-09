import 'package:intl/intl.dart';

class AppFormatters {
  const AppFormatters._();

  static final _number = NumberFormat.decimalPattern('id_ID');
  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static String rupiah(num? value) => 'Rp${_number.format(value ?? 0)}';
  static String date(DateTime? value) => value == null
      ? '-'
      : '${value.day} ${_months[value.month - 1]} ${value.year}';
  static String shortDate(DateTime? value) => value == null
      ? '-'
      : '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/${value.year}';
  static String monthYear(DateTime value) =>
      '${_months[value.month - 1]} ${value.year}';
}
