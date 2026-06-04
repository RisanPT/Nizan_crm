import 'dart:typed_data';
import 'image_download_service_stub.dart'
    if (dart.library.io) 'image_download_service_mobile.dart'
    if (dart.library.html) 'image_download_service_web.dart'
    as impl;

Future<void> downloadImage(
  Uint8List bytes,
  String fileName, {
  String? subject,
  String? text,
}) {
  return impl.downloadImage(
    bytes,
    fileName,
    subject: subject,
    text: text,
  );
}
