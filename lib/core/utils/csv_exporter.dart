import 'web_download.dart';

class CsvExporter {
  const CsvExporter._();

  static void download({
    required String filename,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln(headers.map(_escape).join(';'));
    for (final row in rows) {
      buffer.writeln(row.map((value) => _escape('$value')).join(';'));
    }
    downloadTextFile(filename, buffer.toString(), 'text/csv;charset=utf-8');
  }

  static String _escape(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
