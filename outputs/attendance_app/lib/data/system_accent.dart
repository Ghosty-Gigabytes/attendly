import 'dart:io';
import 'package:flutter/services.dart';

class SystemAccent {
  static const channel = MethodChannel('dev.attendly/theme');
  static Future<int?> read() async {
    if (!Platform.isAndroid) return null;
    try {
      return await channel.invokeMethod<int>('systemAccent');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
