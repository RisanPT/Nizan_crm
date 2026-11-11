import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configureDioWeb(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is BrowserHttpClientAdapter) {
    adapter.enableCORSWarning = false;
  }
}

