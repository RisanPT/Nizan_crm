import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadImage(
  Uint8List bytes,
  String fileName, {
  String? subject,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  final xf = XFile(file.path, mimeType: 'image/jpeg', name: fileName);
  await Share.shareXFiles([xf], subject: subject, text: text);
}
