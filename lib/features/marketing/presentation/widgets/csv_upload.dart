import 'dart:async';
import 'package:universal_html/html.dart' as html;

/// Opens the browser file picker and returns the chosen CSV file's text.
/// Web-oriented (the marketing module runs in the web/desktop admin app);
/// returns null if the user cancels. A paste-text fallback is offered in the UI
/// for any platform where this no-ops.
Future<String?> pickCsvFileText() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = '.csv,text/csv';
  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) completer.complete(reader.result as String?);
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsText(files.first);
  });
  input.click();
  return completer.future;
}
