import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/portal_parser.dart';

void main() {
  final parser = PortalParser();
  const unselected =
      '<select name="sem"><option value="1">1</option><option value="5">5</option></select>';
  test('current semester overrides default first dropdown option', () {
    expect(parser.attendanceSemester(unselected, '5'), '5');
  });
  test('current semester overrides stale selected option', () {
    expect(
      parser.attendanceSemester(
        unselected.replaceFirst('value="1"', 'value="1" selected'),
        '5',
      ),
      '5',
    );
  });
  test('explicit selection works without course metadata', () {
    expect(
      parser.attendanceSemester(
        unselected.replaceFirst('value="5"', 'value="5" selected'),
        null,
      ),
      '5',
    );
  });
  test('first option alone cannot establish the current semester', () {
    expect(
      () => parser.attendanceSemester(unselected, null),
      throwsA(isA<PortalException>()),
    );
  });
}
