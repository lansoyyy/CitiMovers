void downloadTextFile({
  required String fileName,
  required String mimeType,
  required String content,
}) {
  throw UnsupportedError('CSV download is only available on web builds.');
}
