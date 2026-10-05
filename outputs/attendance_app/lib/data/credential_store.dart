import 'package:flutter/services.dart';

class SavedLogin {
  final String username, password;
  const SavedLogin(this.username, this.password);
}

class CredentialStore {
  static const channel = MethodChannel('dev.attendly/credentials');
  Future<SavedLogin?> read() async {
    final value = await channel.invokeMapMethod<String, String>('read');
    if (value == null) return null;
    return SavedLogin(value['username']!, value['password']!);
  }

  Future<void> write(String username, String password) => channel.invokeMethod(
    'write',
    {'username': username, 'password': password},
  );
  Future<void> clear() => channel.invokeMethod('clear');
}
