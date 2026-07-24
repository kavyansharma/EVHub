import 'dart:convert';
import 'dart:typed_data';

import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

class FileDownloadHelper {
  /// Downloads a CSV string as a file cross-platform (Web & Native stubs)
  static void downloadCsv({required String csvContent, required String filename}) {
    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    downloadBytesHelper(bytes, filename);
  }
}
