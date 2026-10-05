import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/portal_parser.dart';
import 'package:attendly/domain/models.dart';

void main() {
  test('each month uses its own subject header order', () {
    final parsed = PortalParser().attendance(
      '<table><tr><td>Days</td><td>A</td><td>B</td></tr><tr><td>Sep-01</td><td>1</td><td>0</td></tr></table>'
      '<table><tr><td>Days</td><td>B</td><td>A</td></tr><tr><td>Overall Class</td><td>20</td><td>20</td></tr><tr><td>Overall Present</td><td>12</td><td>18</td></tr></table>',
      const [Subject('A','A',Counts(0,0),0),Subject('B','B',Counts(0,0),0)], '2026-27');
    expect(parsed.subjects.singleWhere((s)=>s.code=='A').official.attended,18);
    expect(parsed.subjects.singleWhere((s)=>s.code=='B').official.attended,12);
  });
  final parser = PortalParser();
  const subjects = [Subject('CS201', 'CS', Counts(0, 0), 0)];
  String page(String totals) =>
      '<table><tr><th>Days</th><th>CS201</th></tr>$totals</table>';
  test('IMS report singular Overall Class imports all seven exact totals', () {
    const codes = [
      'DNCP0503',
      'EAEPC501',
      'EAEPC502',
      'EAEPC503',
      'EAEPC504',
      'EAEPE501',
      'EMPH0601',
    ];
    final result = parser.attendance(
      File('test/fixtures/ims_attendance_totals.html').readAsStringSync(),
      codes.reversed
          .map((code) => Subject(code, code, const Counts(0, 0), 0))
          .toList(),
      '2026-27',
    );
    expect(result.subjects.map((s) => s.code), codes);
    expect(result.subjects.map((s) => s.official.attended), [
      0,
      19,
      12,
      17,
      22,
      20,
      13,
    ]);
    expect(result.subjects.map((s) => s.official.held), [
      0,
      28,
      18,
      26,
      26,
      27,
      20,
    ]);
    expect(
      result.days
          .singleWhere((d) => d.subject == 'EAEPC504' && d.date == '2026-07-28')
          .raw,
      'NT+NT',
    );
    expect(
      result.days
          .singleWhere((d) => d.subject == 'EMPH0601' && d.date == '2026-10-02')
          .raw,
      'GH',
    );
    expect(
      result.days
          .singleWhere((d) => d.subject == 'EMPH0601' && d.date == '2026-10-06')
          .raw,
      '',
    );
  });
  test('overall held is recognized as the subject denominator', () {
    final result = parser.attendance(
      page(
        '<tr><td>Overall Classes Held</td><td>20</td></tr><tr><td>Overall Present</td><td>17</td></tr>',
      ),
      subjects,
      '2026-27',
    );
    expect(result.subjects.single.official.held, 20);
    final held = parser.attendance(
      page(
        '<tr><td>Overall Held</td><td>20</td></tr><tr><td>Overall Present</td><td>17</td></tr>',
      ),
      subjects,
      '2026-27',
    );
    expect(held.subjects.single.official.attended, 17);
    expect(held.subjects.single.official.held, 20);
  });
  test(
    'missing totals error identifies the missing metric and observed labels',
    () {
      expect(
        () => parser.attendance(
          page(
            '<tr><td>Overall Present</td><td>17</td></tr><tr><td>Overall Unknown</td><td>20</td></tr>',
          ),
          subjects,
          '2026-27',
        ),
        throwsA(
          isA<PortalException>().having(
            (e) => e.message,
            'diagnostic',
            allOf(
              contains('Missing held-class count for CS201'),
              contains('Overall Present | Overall Unknown'),
            ),
          ),
        ),
      );
    },
  );
  test('outer IMS frameset is identified separately from missing totals', () {
    expect(
      () => parser.attendance(
        '<html><frameset><frame name="data"></frameset></html>',
        subjects,
        '2026-27',
      ),
      throwsA(
        isA<PortalException>().having(
          (e) => e.message,
          'diagnostic',
          contains('outer frameset'),
        ),
      ),
    );
  });
}
