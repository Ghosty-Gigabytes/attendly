import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/portal_parser.dart';
import 'package:attendly/domain/models.dart';

void main() {
  final parser = PortalParser();
  const registered = [Subject('A', 'Algebra', Counts(0,0), 1), Subject('B', 'No classes yet', Counts(0,0), 2)];
  String report(String header, String present, String held) => '<table><tr><td>Days</td>$header</tr><tr><td>Oct-06</td>$present</tr><tr><td>Overall Present</td>$present</tr><tr><td>Overall Class</td>$held</tr></table>';
  test('registered courses without attendance columns are not imported', () {
    final r = parser.attendance(report('<td>A</td>', '<td>1</td>', '<td>2</td>'), registered, '2026-27');
    expect(r.subjects.map((s)=>s.code), ['A']);
    expect(r.subjects.single.name, 'Algebra');
    expect(r.subjects.single.official.held, 2);
    expect(r.days.single.subject, 'A');
  });
  test('attendance-only subjects and absent metadata still import', () {
    final html = report('<td>C</td><td>A</td>', '<td>1</td><td>0</td>', '<td>2</td><td>1</td>');
    for (final metadata in [registered, <Subject>[]]) {
      final r = parser.attendance(html, metadata, '2026-27');
      expect(r.subjects.map((s)=>s.code), ['C','A']);
      expect(r.subjects.first.name, 'C');
      expect(r.subjects.first.official.attended, 1);
    }
  });
  test('different monthly headers are mapped independently', () {
    final r = parser.attendance(report('<td>A</td>', '<td>1</td>', '<td>2</td>') + report('<td>C</td>', '<td>0</td>', '<td>1</td>'), registered, '2026-27');
    expect(r.subjects.map((s)=>s.code), ['A','C']);
    expect(r.days.map((d)=>d.subject), ['A','C']);
  });
  test('duplicate headers and missing values still fail safely', () {
    expect(() => parser.attendance(report('<td>A</td><td>A</td>', '<td>1</td><td>1</td>', '<td>2</td><td>2</td>'), registered, '2026-27'), throwsA(isA<PortalException>()));
    expect(() => parser.attendance(report('<td>A</td><td>C</td>', '<td>1</td>', '<td>2</td>'), registered, '2026-27'), throwsA(isA<PortalException>()));
  });
  test('empty spacer headers retain later subject column positions', () {
    final r = parser.attendance(report('<td>A</td><td>&nbsp;</td><td>C</td><td></td>', '<td>1</td><td></td><td>0</td><td></td>', '<td>2</td><td></td><td>3</td><td></td>'), registered, '2026-27');
    expect(r.subjects.map((s) => s.code), ['A', 'C']);
    expect(r.subjects.last.official.held, 3);
    expect(r.days.last.raw, '0');
  });
  test('unnamed columns containing attendance are not silently dropped', () {
    expect(() => parser.attendance(report('<td>A</td><td></td>', '<td>1</td><td>0</td>', '<td>2</td><td>1</td>'), registered, '2026-27'), throwsA(isA<PortalException>()));
  });
}
