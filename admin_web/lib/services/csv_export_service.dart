import 'csv_export_downloader_stub.dart'
    if (dart.library.html) 'csv_export_downloader_web.dart'
    as downloader;

class AdminCsvExportService {
  static String buildCsv({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer()..writeln(headers.map(_escapeCsv).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsv).join(','));
    }
    return buffer.toString();
  }

  static void downloadCsv({
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final csv = buildCsv(headers: headers, rows: rows);
    downloader.downloadTextFile(
      fileName: fileName,
      mimeType: 'text/csv;charset=utf-8',
      content: csv,
    );
  }

  static String _escapeCsv(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final escaped = normalized.replaceAll('"', '""');
    return '"$escaped"';
  }
}
