import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> downloadImage(
  Uint8List bytes,
  String fileName, {
  String? subject,
  String? text,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/jpeg'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = objectUrl
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(objectUrl);
}
