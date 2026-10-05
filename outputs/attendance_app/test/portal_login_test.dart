import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/data/portal_parser.dart';

class ImsAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  final String page = File('test/fixtures/ims_login.html').readAsStringSync();
  bool reject = false, invalidImage = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = requestStream == null
        ? <int>[]
        : await requestStream.fold<List<int>>([], (a, b) => a..addAll(b));
    bodies.add(utf8.decode(bytes));
    if (options.uri.path == '/imsnsit') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/imsnsit/'],
          'set-cookie': [
            'IMSSESSION=test-session; Domain=.imsnsit.org; Path=/; Secure; HttpOnly',
          ],
        },
      );
    }
    if (options.uri.path == '/imsnsit/student_login110.php') {
      return ResponseBody.fromString(page, 200);
    }
    if (options.uri.path == '/imsnsit/captcha.php') {
      return invalidImage
          ? ResponseBody.fromString('<html>Session error</html>', 200)
          : ResponseBody.fromBytes(
              [0xff, 0xd8, 0xff, 0xe0],
              200,
              headers: {
                'content-type': ['image/jpeg'],
              },
            );
    }
    if (options.method == 'POST') {
      return ResponseBody.fromString(
        reject
            ? '$page Please try again'
            : '<font>Welcome : Student</font><a href="profile.php">My Profile</a><a href="activity.php">My Activities</a>',
        200,
      );
    }
    if (options.uri.path == '/imsnsit/activity.php') {
      return ResponseBody.fromString(page, 200);
    }
    return ResponseBody.fromString('<html>IMS</html>', 200);
  }

  @override
  void close({bool force = false}) {}
}

String? header(RequestOptions r, String key) => r.headers.entries
    .where((e) => e.key.toLowerCase() == key.toLowerCase())
    .firstOrNull
    ?.value
    .toString();

void main() {
  test('current IMS legacy HTML token is selected globally like Python', () {
    final parser = PortalParser(),
        source = File('test/fixtures/ims_login.html').readAsStringSync();
    final form = parser.loginChallenge(source);
    expect(form.fields['HRAND_NUM'], 'REDACTED_CHALLENGE');
    expect(
      form.captcha.toString(),
      'https://imsnsit.org/imsnsit/captcha.php?token=REDACTED',
    );
  });
  test(
    'verified IMS request order, cookie continuity and encoded POST are preserved',
    () async {
      final portal = PortalService(), adapter = ImsAdapter();
      portal.dio.httpClientAdapter = adapter;
      addTearDown(() => portal.dio.close());
      final challenge = await portal.challenge();
      expect(adapter.requests.map((r) => r.uri.path), [
        '/imsnsit',
        '/imsnsit/',
        '/imsnsit/student_login110.php',
        '/imsnsit/captcha.php',
      ]);
      expect(adapter.requests.first.uri.host, 'www.imsnsit.org');
      for (final request in adapter.requests.skip(2)) {
        expect(
          header(request, 'User-Agent'),
          PortalService.baseHeaders['User-Agent'],
        );
        expect(
          header(request, 'Referer'),
          'https://www.imsnsit.org/imsnsit/student_login.php',
        );
        expect(header(request, 'Origin'), 'https://www.imsnsit.org');

        expect(header(request, 'Cookie'), contains('IMSSESSION=test-session'));
      }
      await portal.login(challenge, '12345', 'a+b & c', ' 1234 ');
      final post = adapter.requests.last;
      expect(
        post.uri.toString(),
        'https://www.imsnsit.org/imsnsit/student_login.php',
      );
      expect(post.method, 'POST');
      expect(Uri.splitQueryString(adapter.bodies.last), {
        'uid': '12345',
        'pwd': 'a+b & c',
        'HRAND_NUM': 'REDACTED_CHALLENGE',
        'fy': '2024-25',
        'comp': 'NETAJI SUBHAS UNIVERSITY OF TECHNOLOGY',
        'cap': '1234',
        'logintype': 'student',
      });
      expect(header(post, 'Cookie'), contains('IMSSESSION=test-session'));
      expect(portal.account, '12345');
    },
  );
  test('CAPTCHA errors and expired sessions are distinguished', () async {
    final portal = PortalService(), adapter = ImsAdapter();
    portal.dio.httpClientAdapter = adapter;
    addTearDown(() => portal.dio.close());
    final challenge = await portal.challenge();
    adapter.reject = true;
    await expectLater(
      portal.login(challenge, 'id', 'password', '1234'),
      throwsA(isA<PortalLoginRejected>()),
    );
    expect(portal.account, isNull);
    adapter.reject = false;
    await portal.login(challenge, 'id', 'password', '1234');
    await expectLater(
      portal.fetchAttendance(),
      throwsA(isA<PortalSessionExpired>()),
    );
    expect(portal.account, isNull);
  });
  test(
    'HTML returned in place of CAPTCHA is reported before image rendering',
    () async {
      final portal = PortalService(),
          adapter = ImsAdapter()..invalidImage = true;
      portal.dio.httpClientAdapter = adapter;
      addTearDown(() => portal.dio.close());
      await expectLater(
        portal.challenge(),
        throwsA(
          isA<PortalException>().having(
            (e) => e.message,
            'message',
            contains('instead of a CAPTCHA'),
          ),
        ),
      );
    },
  );
}
