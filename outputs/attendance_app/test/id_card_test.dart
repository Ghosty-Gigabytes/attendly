import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/id_card_parser.dart';
import 'package:attendly/data/portal_parser.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/domain/student_id.dart';

const idHtml = '''<table>
<tr><td>Name</td><td>: TEST STUDENT</td><td>ID No: 2024TEST001</td></tr>
<tr><td>Father's Name</td><td>: TEST PARENT</td><td rowspan="6"><img src="photo.jpg?token=ephemeral" width="100" height="100"></td></tr>
<tr><td>Program</td><td>: B.Tech.</td></tr>
<tr><td>Department</td><td>: ELECTRONICS AND COMMUNICATION ENGINEERING(EAST)</td></tr>
<tr><td>Specialization</td><td>: SPECIALIZATION NOT BRANCH</td></tr>
<tr><td>Date Of Issue</td><td>: 02-08-2024</td></tr></table><table>
<tr><td>DOB</td><td>: 01-01-2006</td></tr>
<tr><td>Program Duration</td><td>: </td></tr>
<tr><td>E-Mail</td><td>: example@example.invalid</td></tr>
<tr><td>Ph.No.</td><td>: 1234567890 (M)</td></tr>
<tr><td>Parent's Contact No</td><td>: 9999999999 (R); 8888888888 (M)</td></tr>
<tr><td>Blood Group</td><td>: O+</td></tr>
<tr><td>Permanent Address</td><td>: Example Street &emsp;<img src="signature.png?token=ephemeral" width="100" height="30"></td></tr>
<tr><td>&nbsp;</td><td>&nbsp;EXAMPLE CITY - 123456</td></tr></table>''';
const banner =
    '<table><tr><td><img src="logo.png?token=ephemeral" height="100" width="100"></td><td>NETAJI SUBHAS UNIVERSITY OF TECHNOLOGY</td></tr></table><a href="activities">My Activities</a>';
final page = Uri.parse('https://www.imsnsit.org/imsnsit/id-details');
StudentIdData fixtureCard() =>
    IdCardParser().parse(idHtml, page, '2024TEST001').student;

class CardAdapter implements HttpClientAdapter {
  final seen = <RequestOptions>[];
  bool imageFailure = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    if (options.uri.path.endsWith('student_login.php')) {
      return ResponseBody.fromString(
        banner,
        200,
        headers: {
          'set-cookie': ['PHPSESSID=test; Path=/; Secure'],
        },
      );
    }
    if (options.uri.path.endsWith('activities')) {
      return ResponseBody.fromString(
        '<a href="personal">Personal Info</a>',
        200,
      );
    }
    if (options.uri.path.endsWith('personal')) {
      return ResponseBody.fromString(
        '<a href="id-details">ID Card Details</a>',
        200,
      );
    }
    if (options.uri.path.endsWith('id-details')) {
      return ResponseBody.fromString(idHtml, 200);
    }
    if (imageFailure) {
      return ResponseBody.fromString('<html>Unavailable</html>', 200);
    }
    return ResponseBody.fromBytes([137, 80, 78, 71, 13, 10, 26, 10], 200);
  }
}

void main() {
  test(
    'maps department and student phone, address continuation and image URLs',
    () {
      final parsed = IdCardParser().parse(idHtml, page, '2024TEST001');
      expect(
        parsed.student.branch,
        'ELECTRONICS AND COMMUNICATION ENGINEERING(EAST)',
      );
      expect(parsed.student.mobile, '1234567890');
      expect(parsed.student.address, 'Example Street, EXAMPLE CITY - 123456');
      expect(parsed.student.batch, '2024–2028');
      expect(parsed.student.dob, '01-01-2006');
      expect(
        parsed.photo.toString(),
        contains('/imsnsit/photo.jpg?token=ephemeral'),
      );
      expect(parsed.signature.toString(), contains('signature.png'));
      expect(
        IdCardParser().logo(banner, page).toString(),
        contains('logo.png'),
      );
      expect(jsonEncode(parsed.student.toJson()), isNot(contains('ephemeral')));
    },
  );
  test(
    'M.Tech has two years, unknown courses do not get an invented duration',
    () {
      expect(
        IdCardParser()
            .parse(idHtml.replaceAll('B.Tech.', 'M.Tech.'), page, '2024TEST001')
            .student
            .batch,
        '2024–2026',
      );
      expect(
        IdCardParser()
            .parse(idHtml.replaceAll('B.Tech.', 'Ph.D.'), page, '2024TEST001')
            .student
            .batch,
        isEmpty,
      );
      expect(
        () => IdCardParser().parse(idHtml, page, 'OTHER'),
        throwsA(isA<PortalException>()),
      );
      expect(
        () => IdCardParser().parse('<html>login</html>', page, '2024TEST001'),
        throwsA(isA<PortalException>()),
      );
    },
  );
  test(
    'IMS images use the authenticated client and are stored as bytes, not URLs',
    () async {
      final service = PortalService();
      final adapter = CardAdapter();
      service.dio.httpClientAdapter = adapter;
      await service.login(
        LoginChallenge(
          PortalForm(page, {'HRAND_NUM': 'test'}, null),
          Uint8List(0),
        ),
        '2024TEST001',
        'password',
        '1234',
      );
      final card = await service.fetchIdCard();
      expect(card.photo, isNotNull);
      expect(card.signature, isNotNull);
      expect(card.logo, isNotNull);
      final images = adapter.seen.where(
        (r) => r.responseType == ResponseType.bytes,
      );
      expect(images.length, 3);
      for (final r in images) {
        expect(r.headers['cookie'].toString(), contains('PHPSESSID=test'));
        expect(r.headers['Referer'].toString(), contains('id-details'));
      }
      expect(StudentIdData.fromJson(card.toJson()).photo, card.photo);
      adapter.imageFailure = true;
      expect((await service.fetchIdCard()).photo, isNull);
    },
  );
  test(
    'offline cached cards stay account scoped and deletion erases images',
    () async {
      final c = AppController(AttendanceDatabase.memory(), PortalService());
      addTearDown(c.dispose);
      c.authenticated = true;
      c.data = const AppData(account: '2024TEST001');
      await c.db.setPreference(
        'idCard:2024TEST001',
        jsonEncode(fixtureCard().toJson()),
      );
      expect((await c.cachedIdCard())?.name, 'TEST STUDENT');
      c.data = const AppData(account: 'OTHER');
      expect(await c.cachedIdCard(), isNull);
      c.data = const AppData(account: '2024TEST001');
      c.authenticated = false;
      expect(await c.cachedIdCard(), isNull);
      c.authenticated = true;
      await c.db.deleteAllLocalData();
      expect(await c.cachedIdCard(), isNull);
    },
  );
}
