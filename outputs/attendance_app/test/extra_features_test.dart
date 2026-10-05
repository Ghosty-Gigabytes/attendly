import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/domain/planner.dart';
import 'package:attendly/domain/export.dart';

void main() {
  test('CSV identifies sources and protects formula-like personal notes', () {
    final text = exportCsv(
      AppData(
        subjects: [const Subject('MA', 'Maths', Counts(18, 24), 0)],
        sessions: [
          Session(
            id: '1',
            subject: 'MA',
            starts: DateTime(2026, 10, 1),
            note: '=1+1',
          ),
        ],
      ),
    );
    expect(text, contains('"official_total"'));
    expect(text, contains('"personal"'));
    expect(text, contains("'=1+1"));
  });
  test('recovery uses remaining timetable and respects its end date', () {
    final day = DateTime(2026, 10, 5);
    final data = AppData(
      subjects: [const Subject('MA', 'Maths', Counts(18, 25), 0)],
      timetable: [
        TimetableRule(
          id: 'r',
          subject: 'MA',
          weekday: 2,
          hour: 9,
          from: day,
          until: DateTime(2026, 10, 20),
        ),
      ],
    );
    final scenario = Scenario(id: '1', name: 'Recovery', from: day, until: day);
    expect(
      recoveryDate(data, scenario, project(data, scenario).single),
      DateTime(2026, 10, 20, 9),
    );
    final short = data.copyWith(
      timetable: [
        TimetableRule(
          id: 'r',
          subject: 'MA',
          weekday: 2,
          hour: 9,
          from: day,
          until: DateTime(2026, 10, 13),
        ),
      ],
    );
    expect(
      recoveryDate(short, scenario, project(short, scenario).single),
      isNull,
    );
  });
  test(
    'suitable dates evaluate every subject and intermediate eligibility',
    () {
      final day = DateTime(2026, 10, 5);
      final data = AppData(
        subjects: [
          const Subject('MA', 'Maths', Counts(18, 24), 0),
          const Subject('CS', 'CS', Counts(29, 30), 0),
        ],
        timetable: [
          TimetableRule(
            id: 'a',
            subject: 'MA',
            weekday: 1,
            hour: 9,
            from: day,
            until: day,
          ),
          TimetableRule(
            id: 'b',
            subject: 'CS',
            weekday: 2,
            hour: 9,
            from: day,
            until: day.add(const Duration(days: 1)),
          ),
        ],
      );
      final plan = Scenario(
        id: '1',
        name: 'test',
        from: day,
        until: day.add(const Duration(days: 1)),
      );
      expect(suitableDays(data, plan), [DateTime(2026, 10, 6)]);
      expect(plan.actions, isEmpty);
    },
  );
}
