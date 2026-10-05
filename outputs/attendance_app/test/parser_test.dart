import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/portal_parser.dart';
import 'package:attendly/domain/models.dart';

void main() {
  final parser = PortalParser();
  test('form extraction preserves tokens and resolves relative targets', () {
    final form = parser.form(
      '<form action="student_login.php"><input name="HRAND_NUM" value="token"><select name="fy"><option>old</option><option value="2026-27" selected>Now</option></select><img id="captchaimg" src="captcha.php"></form>',
      Uri.parse('https://imsnsit.org/imsnsit/student_login110.php'),
      'HRAND_NUM',
    );
    expect(form.fields['fy'], '2026-27');
    expect(form.fields['HRAND_NUM'], 'token');
    expect(form.action.path, '/imsnsit/student_login.php');
    expect(form.captcha!.path, '/imsnsit/captcha.php');
  });
  test('subject columns are mapped by code regardless of registration order', () {
    const subjects = [
      Subject('MA201', 'Maths', Counts(0, 0), 0),
      Subject('CS201', 'CS', Counts(0, 0), 0),
    ];
    final result = parser.attendance(
      '''<table><tr><th>Date</th><th>CS201</th><th>MA201</th></tr><tr><td>Oct-01</td><td>P</td><td>A</td></tr><tr><td>Overall Total Classes</td><td>20</td><td>24</td></tr><tr><td>Overall Total Present</td><td>17</td><td>18</td></tr></table>''',
      subjects,
      '2026-27',
    );
    expect(
      result.subjects.singleWhere((s) => s.code == 'MA201').official.attended,
      18,
    );
    expect(
      result.subjects.singleWhere((s) => s.code == 'CS201').official.attended,
      17,
    );
    expect(result.days.first.date, '2026-10-01');
    expect(result.days.first.subject, 'CS201');
  });
  test(
    'unknown headers and malformed counts fail instead of producing empty success',
    () {
      expect(
        () => parser.attendance(
          '<table><tr><td>Overall Total Classes</td><td>24</td></tr></table>',
          [const Subject('MA', 'Maths', Counts(0, 0), 0)],
          '2026-27',
        ),
        throwsA(isA<PortalException>()),
      );
      expect(
        () => parser.parseDate('Feb-30', '2026-27'),
        throwsA(isA<PortalException>()),
      );
      expect(parser.parseDate('Jan-02', '2026-27'), DateTime(2027, 1, 2));
    },
  );
  test('course discovery uses named headers and semester context', () {
    final result = parser.courses(
      '<div>Semester 3</div><table><tr><th>No.</th><th>Course Code</th><th>Course Name</th></tr><tr><td>1</td><td>MA201</td><td>Maths</td></tr></table>',
    );
    expect(result.semester, '3');
    expect(result.subjects.single.code, 'MA201');
  });
}
