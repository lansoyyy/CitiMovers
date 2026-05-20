import 'csv_export_downloader_stub.dart'
    if (dart.library.html) 'csv_export_downloader_web.dart'
    as downloader;

class AdminCsvExportService {
  /// UTF-8 byte order mark so Excel opens the file as UTF-8 (fixes em-dash mojibake).
  static const String utf8Bom = '\uFEFF';

  /// Normalizes text for Excel-friendly CSV (dashes, quotes, common mojibake).
  static String normalizeExportText(String value) {
    return value
        .replaceAll('\u2014', ' - ')
        .replaceAll('\u2013', ' - ')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll(RegExp(r'â€["""]'), ' - ')
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€\u009d', '"');
  }

  static String buildCsv({
    required List<String> headers,
    required List<List<String>> rows,
    bool includeUtf8Bom = true,
  }) {
    final buffer = StringBuffer();
    if (includeUtf8Bom) {
      buffer.write(utf8Bom);
    }
    buffer.writeln(headers.map(_escapeCsv).join(','));
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
    final normalized = normalizeExportText(value)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final escaped = normalized.replaceAll('"', '""');
    return '"$escaped"';
  }
}
