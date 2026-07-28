import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:nizan_crm/models/customer.dart';
import 'client_report_html.dart';

Future<void> printClientsReport(List<Customer> clients) async {
  final content = buildClientsReportHtml(clients);
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
    ..style.position = 'fixed'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = '0'
    ..src = objectUrl;

  web.document.body?.append(iframe);

  iframe.onLoad.listen((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final frameWindow = iframe.contentWindow;
    if (frameWindow != null) {
      try {
        frameWindow.focus();
        frameWindow.print();
      } catch (_) {
        try {
          web.window.print();
        } catch (_) {}
      }
    }
    Future<void>.delayed(const Duration(seconds: 2), () {
      web.URL.revokeObjectURL(objectUrl);
      iframe.remove();
    });
  });
}
