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
    Future<Response<dynamic>> send() => dio.post<dynamic>(
      path,
      data: data,
      options: Options(headers: {'X-CSRF-TOKEN': _csrf}),
    );
    late Response<dynamic> response;
    try {
      response = await send();
    } on DioException catch (e) {
      // Retry only an explicit CSRF rejection: the server has not executed
      // the mutation. Never retry arbitrary failures or rejected credentials.
      if (e.response?.statusCode != 403 ||
          e.response?.data is! Map ||
          (e.response!.data as Map)['code'] != 'CSRF_INVALID') {
        rethrow;
      }
      await csrf();
      response = await send();
    }
    return response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : {};
  }

  Future<void> logout() async {
    await post('/auth/logout');
    _csrf = null;
  }

  Future<Map<String, dynamic>> imsLogin(Map<String, dynamic> fields) async {
    final user = await post('/auth/ims/login', fields);
    _csrf = null;
    await csrf();
    return user;
  }

  static String message(Object error) =>
      error is DioException && error.response?.data is Map
      ? (error.response!.data as Map)['message']?.toString() ??
            (error.response?.statusCode == 401
                ? 'Your Attendly session expired. Please sign in again.'
                : error.response?.statusCode == 403
                ? 'Your session expired. Reload the page and sign in again.'
                : 'The request could not be completed.')
      : 'Could not connect. Your saved records are still available.';
}
