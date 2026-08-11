// Save raw bytes as a downloaded file. Web → browser download; mobile → share
// sheet; other → no-op.
import 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_mobile.dart'
    if (dart.library.html) 'file_saver_web.dart' as impl;

Future<void> saveFileBytes(
  String filename,
  List<int> bytes, {
  String mime = 'application/octet-stream',
}) =>
    impl.saveFileBytes(filename, bytes, mime: mime);
