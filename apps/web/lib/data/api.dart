import 'package:dio/dio.dart';
import 'http_adapter.dart' if (dart.library.js_interop) 'http_adapter_web.dart';

class Api {
  static const base = String.fromEnvironment('API_BASE', defaultValue: '/api');
  final Dio dio;
  Api({Dio? client})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: base,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 90),
            ),
          ) {
    configureBrowser(dio);
  }
  String? _csrf;
  Future<Map<String, dynamic>> get(String path) async =>
      Map<String, dynamic>.from((await dio.get<dynamic>(path)).data as Map);
  Future<void> csrf() async {
    _csrf = (await get('/auth/csrf'))['token'] as String;
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    if (_csrf == null) await csrf();
    final response = await dio.post<dynamic>(
      path,
      data: data,
      options: Options(headers: {'X-CSRF-TOKEN': _csrf}),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : {};
  }

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? name,
  }) async {
    final user = await post(name == null ? '/auth/login' : '/auth/signup', {
      'email': email.trim(),
      'password': password,
      if (name != null) 'name': name.trim(),
    });
    _csrf = null;
    await csrf();
    return user;
  }

  Future<void> logout() async {
    await post('/auth/logout');
    _csrf = null;
  }

  void google() => navigateTo(
    '${base.replaceFirst(RegExp(r'/api/?$'), '')}/oauth2/authorization/google',
  );
  static String message(Object error) =>
      error is DioException && error.response?.data is Map
      ? (error.response!.data as Map)['message']?.toString() ??
            'The request could not be completed.'
      : 'Could not connect. Your saved records are still available.';
}
