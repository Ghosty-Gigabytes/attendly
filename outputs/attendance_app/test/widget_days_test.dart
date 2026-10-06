import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/domain/widget_days.dart';

void main() {
  final now = DateTime(2026, 10, 4); // Sunday
  TimetableRule rule(int day, int weight) => TimetableRule(
    id: '$day',
    subject: 'A',
    weekday: day,
    hour: 9,
    weight: weight,
    from: now,
    until: DateTime(2026, 12, 1),
  );
  final data = AppData(timetable: [rule(1, 2), rule(2, 1)]);
  Subject subject(int a, int t) => Subject('A', 'Algebra', Counts(a, t), 0);
  test('two classes on one date count as one skip day', () {
    expect(
      widgetDayAdvice(data, subject(9, 10), now: now),
      'Skip ~1 class days',
    );
  });
  test('recovery groups multiple classes into teaching days', () {
    expect(
      widgetDayAdvice(data, subject(6, 10), now: now),
      'Attend ~4 days to 75%',
    );
  });
  test('without timetable no days are invented', () {
    expect(
      widgetDayAdvice(const AppData(), subject(6, 10), now: now),
      contains('Need 6 classes'),
    );
    expect(
      widgetDayAdvice(data, subject(0, 0), now: now),
      'No classes recorded',
    );
    expect(widgetDayAdvice(data, subject(3, 4), now: now), 'Skip 0 days');
  });
  test('expired timetable does not promise recovery days', () {
    expect(
      widgetDayAdvice(data, subject(6, 10), now: DateTime(2027)),
      contains('extend timetable'),
    );
  });
}
