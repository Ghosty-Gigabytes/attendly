import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:web/web.dart' as web;

void configureBrowser(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}

void navigateTo(String location) {
  web.window.location.assign(location);
}
