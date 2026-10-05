import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../domain/models.dart';
import 'portal_parser.dart';

class LoginChallenge {
  final PortalForm form;
  final Uint8List image;

  const LoginChallenge(this.form, this.image);
}

class PortalService {
  final PortalParser parser = PortalParser();
  final CookieJar cookies = CookieJar();
  late final Dio dio;

  String? _account;
  Uri? _activity;
  bool _initialized = false;

  String? get account => _account;

  // Match the working Python implementation exactly.
  static final Uri root = Uri.parse('https://www.imsnsit.org/imsnsit/');

  static const Map<String, String> baseHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.6099.119 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  PortalService() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
        followRedirects: false,
        headers: baseHeaders,
      ),
    );

    dio.interceptors.add(CookieManager(cookies));
  }

  void _allow(Uri uri) {
    if (uri.scheme != 'https' ||
        !['imsnsit.org', 'www.imsnsit.org'].contains(uri.host) ||
        uri.port != 443) {
      throw const PortalException(
        'The portal returned an unexpected destination.',
      );
    }
  }

  Future<Response<dynamic>> request(
    Uri uri, {
    Map<String, String>? form,
    bool bytes = false,
  }) async {
    for (var redirects = 0; redirects < 6; redirects++) {
      _allow(uri);

      final response = await dio.requestUri(
        uri,
        data: form,
        options: Options(
          method: form == null ? 'GET' : 'POST',
          responseType: bytes ? ResponseType.bytes : ResponseType.plain,
          contentType: form == null ? null : Headers.formUrlEncodedContentType,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
        ),
      );

      if (response.statusCode! < 300) {
        return response;
      }

      final location = response.headers.value('location');

      if (location == null) {
        throw const PortalException(
          'The portal returned an incomplete redirect.',
        );
      }

      uri = uri.resolve(location);

      // Preserve POST for 307/308.
      // For 301/302/303, switch to GET.
      if (response.statusCode != 307 && response.statusCode != 308) {
        form = null;
      }
    }

    throw const PortalException('Too many portal redirects.');
  }

  Future<LoginChallenge> challenge() async {
    if (!_initialized) {
      // Match Python:
      // self.s.get("https://www.imsnsit.org/imsnsit")
      await request(Uri.parse('https://www.imsnsit.org/imsnsit'));

      _initialized = true;
    }

    // Match Python authenticator() headers.
    dio.options.headers.addAll({
      'Referer': 'https://www.imsnsit.org/imsnsit/student_login.php',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Origin': 'https://www.imsnsit.org',
    });

    final response = await request(root.resolve('student_login110.php'));

    final form = parser.loginChallenge(response.data.toString());

    if (form.captcha == null) {
      throw const PortalException('CAPTCHA URL was not found.');
    }

    final image = await request(form.captcha!, bytes: true);

    final bytes = Uint8List.fromList(List<int>.from(image.data));

    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;

    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;

    final gif =
        bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46;

    if (!jpeg && !png && !gif) {
      throw const PortalException(
        'IMS returned a page instead of a CAPTCHA image. '
        'Refresh the CAPTCHA.',
      );
    }

    return LoginChallenge(form, bytes);
  }

  Future<void> login(
    LoginChallenge challenge,
    String username,
    String password,
    String captcha,
  ) async {
    if ([username.trim(), password, captcha.trim()].any((s) => s.isEmpty)) {
      throw const PortalException(
        'Enter your student ID, password and CAPTCHA.',
      );
    }

    // Match the Python payload exactly.
    final fields = {
      'uid': username.trim(),
      'pwd': password,
      'HRAND_NUM': challenge.form.fields['HRAND_NUM']!,
      'fy': '2024-25',
      'comp': 'NETAJI SUBHAS UNIVERSITY OF TECHNOLOGY',
      'cap': captcha.trim(),
      'logintype': 'student',
    };

    final loginUri = Uri.parse(
      'https://www.imsnsit.org/imsnsit/student_login.php',
    );

    // DEBUG: inspect the session before POST.

    final response = await request(loginUri, form: fields);

    // DEBUG: inspect the complete HTTP response.
    final body = response.data?.toString() ?? '';

    if (body.contains('HRAND_NUM')) {
      final text = parser.parse(body).body?.text.toLowerCase() ?? '';

      if (text.contains('password') &&
          (text.contains('invalid') || text.contains('does not match'))) {
        throw const PortalLoginRejected(
          'The portal rejected the password. '
          'Check it before retrying.',
        );
      }

      if (text.contains('please try again') ||
          text.contains('invalid security')) {
        throw const PortalLoginRejected(
          'The CAPTCHA was rejected. '
          'A fresh image is being loaded.',
        );
      }

      if (text.contains('you are not authorized')) {
        throw const PortalLoginRejected(
          'IMS did not recognize this student ID. '
          'Check it and try again.',
        );
      }

      throw const PortalLoginRejected(
        'IMS rejected the login. '
        'Check your credentials and the new CAPTCHA.',
      );
    }

    /*
     * IMPORTANT:
     *
     * The Python implementation considers the login successful
     * when:
     *
     *   status_code == 200
     *   AND "HRAND_NUM" is not in the response.
     *
     * We preserve that behavior here.
     */

    try {
      _activity = parser.link(body, response.realUri, 'My Activities');
    } on PortalException {
      final doc = parser.parse(body);
      final links = doc.querySelectorAll('a');

      if (!(doc.body?.text.contains('Welcome :') ?? false) ||
          links.length < 2 ||
          links[1].attributes['href'] == null) {
        throw const PortalException(
          'IMS did not return an authenticated student page. '
          'Please try signing in again.',
        );
      }

      _activity = response.realUri.resolve(links[1].attributes['href']!);
    }

    _account = username.trim();
  }

  // Future<AppData> fetchAttendance() async {
  //   if (_activity == null || _account == null) {
  //     throw const PortalSessionExpired();
  //   }
  //
  //   final menu = await request(_activity!);
  //
  //   _checkSession(menu);
  //
  //   final activityHtml =
  //   menu.data.toString();
  //
  //   final coursesUrl = parser.link(
  //     activityHtml,
  //     menu.realUri,
  //     'Current Sem Courses Registered.',
  //   );
  //
  //   final attendanceUrl = parser.link(
  //     activityHtml,
  //     menu.realUri,
  //     'My Attendance',
  //   );
  //
  //   final coursePage = await request(coursesUrl);
  //
  //   _checkSession(coursePage);
  //
  //   final courses = parser.courses(
  //     coursePage.data.toString(),
  //   );
  //
  //   final attendancePage =
  //   await request(attendanceUrl);
  //
  //   _checkSession(attendancePage);
  //
  //   final form = parser.form(
  //     attendancePage.data.toString(),
  //     attendancePage.realUri,
  //     'enc_year',
  //   );
  //
  //   final fields = {
  //     ...form.fields,
  //     'sem': courses.semester,
  //     'submit': 'Submit',
  //   };
  //
  //   final year = fields['year'];
  //
  //   if (year == null ||
  //       !RegExp(r'^\d{4}-\d{2,4}$')
  //           .hasMatch(year)) {
  //     throw const PortalException(
  //       'The attendance academic year could not be verified.',
  //     );
  //   }
  //
  //   final result = await request(
  //     form.action,
  //     form: fields,
  //   );
  //
  //   _checkSession(result);
  //
  //   final attendance = parser.attendance(
  //     result.data.toString(),
  //     courses.subjects,
  //     year,
  //   );
  //
  //   return AppData(
  //     subjects: attendance.subjects,
  //     officialDays: attendance.days,
  //     account: _account!,
  //     semester:
  //     '$year · Semester ${courses.semester}',
  //     synced: DateTime.now(),
  //   );
  // }
  Future<AppData> fetchAttendance() async {
    try {
      // ------------------------------------------------------------
      // 1. Make sure we have an authenticated session
      // ------------------------------------------------------------
      if (_activity == null || _account == null) {
        throw const PortalSessionExpired();
      }

      // ------------------------------------------------------------
      // 2. Fetch My Activity page
      // ------------------------------------------------------------
      final activityResponse = await request(_activity!);

      _checkSession(activityResponse);

      final activityHtml = activityResponse.data.toString();

      // ------------------------------------------------------------
      // 3. Get academic year from the SELECTED option on
      //    My Activity
      // ------------------------------------------------------------
      final academicYear = _extractAcademicYear(activityHtml);

      // ------------------------------------------------------------
      // 4. Find Current Sem Courses Registered
      // ------------------------------------------------------------
      final coursesUrl = parser.link(
        activityHtml,
        activityResponse.realUri,
        'Current Sem Courses Registered.',
      );

      // ------------------------------------------------------------
      // 5. Fetch courses
      // ------------------------------------------------------------
      final coursePage = await request(coursesUrl);

      _checkSession(coursePage);

      final coursesHtml = coursePage.data.toString();

      final courses = parser.courses(coursesHtml);

      // ------------------------------------------------------------
      // 6. Find My Attendance
      // ------------------------------------------------------------
      final attendanceUrl = parser.link(
        activityHtml,
        activityResponse.realUri,
        'My Attendance',
      );

      // ------------------------------------------------------------
      // 7. Fetch attendance page
      // ------------------------------------------------------------
      final attendancePage = await request(attendanceUrl);

      _checkSession(attendancePage);

      final attendanceHtml = attendancePage.data.toString();

      // ------------------------------------------------------------
      // 8. Parse attendance form
      // ------------------------------------------------------------
      final form = parser.form(
        attendanceHtml,
        attendancePage.realUri,
        'enc_year',
      );

      // ------------------------------------------------------------
      // 9. Build POST fields
      //
      // IMPORTANT:
      // year comes from My Activity.
      // sem comes from Current Sem Courses Registered.
      // ------------------------------------------------------------
      final fields = <String, String>{
        ...form.fields,
        'year': academicYear,
        'sem': courses.semester,
        'submit': 'Submit',
      };

      // ------------------------------------------------------------
      // 10. Submit attendance form
      // ------------------------------------------------------------
      final result = await request(form.action, form: fields);

      _checkSession(result);

      final resultHtml = result.data.toString();

      // ------------------------------------------------------------
      // 11. Parse attendance
      // ------------------------------------------------------------
      final attendance = parser.attendance(
        resultHtml,
        courses.subjects,
        academicYear,
      );

      // ------------------------------------------------------------
      // 12. Return AppData
      // ------------------------------------------------------------
      return AppData(
        subjects: attendance.subjects,
        officialDays: attendance.days,
        account: _account!,
        semester: '$academicYear · Semester ${courses.semester}',
        synced: DateTime.now(),
      );
    } on DioException catch (e) {
      throw PortalException(
        'Failed to fetch attendance: ${e.message ?? e.toString()}',
      );
    } catch (e) {
      if (e is PortalException) {
        rethrow;
      }

      throw PortalException('Failed to fetch attendance: $e');
    }
  }

  void _checkSession(Response<dynamic> response) {
    if (response.data.toString().contains('HRAND_NUM')) {
      _account = null;
      _activity = null;

      throw const PortalSessionExpired();
    }
  }

  Future<void> logout() async {
    _account = null;
    _activity = null;
    _initialized = false;

    dio.options.headers.clear();
    dio.options.headers.addAll(baseHeaders);

    await cookies.deleteAll();
  }

  String _extractAcademicYear(String html) {
    final doc = parser.parse(html);

    final yearSelect = doc.querySelector('select#year[name="year"]');
    final selectedOption = yearSelect?.querySelector('option[selected]');

    final year = selectedOption?.attributes['value']?.trim();

    if (year == null || !RegExp(r'^\d{4}-\d{2,4}$').hasMatch(year)) {
      throw const PortalException(
        'Could not determine the current academic year from My Activity.',
      );
    }

    return year;
  }
}
