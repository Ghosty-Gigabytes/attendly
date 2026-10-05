import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class CaptchaService {
  static const _channel = MethodChannel('dev.attendly/ocr');
  Future<String?> recognize(Uint8List image) async {
    ByteData model;
    // A missing custom model is expected on a fresh checkout; manual entry works.
    try {
      model = await rootBundle.load('assets/tessdata/mydigits.traineddata');
    } catch (_) {
      return null;
    }
    final dir = await getTemporaryDirectory();
    final support = await getApplicationSupportDirectory();
    final tessdata = Directory('${support.path}/ocr/tessdata');
    await tessdata.create(recursive: true);
    await File('${tessdata.path}/mydigits.traineddata').writeAsBytes(
      model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
      flush: true,
    );
    final file = File(
      '${dir.path}/captcha-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    try {
      await file.writeAsBytes(image, flush: true);
      final text =
          await _channel.invokeMethod<String>('recognize', {
            'imagePath': file.path,
            'dataPath': '${support.path}/ocr',
          }) ??
          '';
      final answer = text.replaceAll(RegExp(r'\s+'), '');
      return RegExp(r'^\d+$').hasMatch(answer) ? answer : null;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
