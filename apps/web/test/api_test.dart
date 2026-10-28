import 'package:attendly_web/data/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'renews a stale CSRF token once before retrying a rejected request',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      var tokens = 0, attempts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.path == '/auth/csrf') {
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {'token': 'token-${++tokens}'},
                ),
              );
            } else if (++attempts == 1) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: request,
                    statusCode: 403,
                    data: {'code': 'CSRF_INVALID'},
                  ),
                ),
              );
            } else {
              expect(request.headers['X-CSRF-TOKEN'], 'token-2');
              handler.resolve(
                Response(requestOptions: request, data: {'ok': true}),
              );
            }
          },
        ),
      );
      expect(await Api(client: dio).post('/ims/challenge'), {'ok': true});
      expect(tokens, 2);
      expect(attempts, 2);
    },
  );

  test('does not retry unrelated forbidden responses', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
    var attempts = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.path == '/auth/csrf') {
            handler.resolve(
              Response(requestOptions: request, data: {'token': 'token'}),
            );
          } else {
            attempts++;
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: 403,
                  data: {'message': 'Denied'},
                ),
              ),
            );
          }
        },
      ),
    );
    await expectLater(
      Api(client: dio).post('/records'),
      throwsA(isA<DioException>()),
    );
    expect(attempts, 1);
  });
}
