import 'dart:typed_data';
import 'package:attendly/data/credential_store.dart';
import 'package:attendly/data/captcha_service.dart';

class MemoryCredentials extends CredentialStore {
  SavedLogin? value;
  MemoryCredentials([this.value]);
  @override
  Future<SavedLogin?> read() async => value;
  @override
  Future<void> write(String username, String password) async {
    value = SavedLogin(username, password);
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FixedCaptcha extends CaptchaService {
  final String? answer;
  FixedCaptcha([this.answer]);
  @override
  Future<String?> recognize(Uint8List image) async => answer;
}
