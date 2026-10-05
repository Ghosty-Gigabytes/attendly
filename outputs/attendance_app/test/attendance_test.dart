import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/domain/planner.dart';

void main() {
  test(
    'exact threshold, recovery and no false eligibility through rounding',
    () {
      expect(const Counts(18, 24).eligible(), true);
      expect(const Counts(18, 24).canMiss(), 0);
      expect(const Counts(18, 25).recover(), 3);
      expect(const Counts(20, 27).eligible(), false);
      expect(const Counts(21, 28).eligible(), true);
      expect(const Counts(74999, 100000).eligible(), false);
      expect(const Counts(0, 0).percent, isNull);
    },
  );
  test('allowance and recovery are maximal/minimal for all small counts', () {
    for (final target in [75, 80, 85, 90, 95]) {
      for (var held = 1; held < 90; held++) {
        for (var attended = 0; attended <= held; attended++) {
          final c = Counts(attended, held),
              miss = c.canMiss(target),
              recovery = c.recover(target);
          expect(
            Counts(attended + recovery, held + recovery).eligible(target),
            true,
          );
          if (recovery > 0) {
            expect(
              Counts(
                attended + recovery - 1,
                held + recovery - 1,
              ).eligible(target),
              false,
            );
          }
          if (c.eligible(target)) {
            expect(Counts(attended, held + miss).eligible(target), true);
            expect(Counts(attended, held + miss + 1).eligible(target), false);
          }
        }
      }
    }
  });
  test(
    'personal records exclude unknown/cancelled and never alter official',
    () {
      const subject = Subject('MA', 'Maths', Counts(18, 24), 0);
      final data = AppData(
        subjects: [subject],
        sessions: [
          for (final status in AttendanceStatus.values)
            Session(
              id: status.name,
              subject: 'MA',
              starts: DateTime(2026, 10, 1),
              status: status,
              weight: 2,
            ),
        ],
      );
      expect(data.personalLog('MA').attended, 2);
      expect(data.personalLog('MA').held, 4);
      expect(data.subjects.single.official.held, 24);
    },
  );
  test(
    'ordered scenario detects a dip even when final attendance recovers',
    () {
      final first = DateTime(2026, 10, 5);
      final data = AppData(
        subjects: [const Subject('MA', 'Maths', Counts(18, 24), 0)],
        timetable: [
          for (var day = 1; day <= 4; day++)
            TimetableRule(
              id: 'r$day',
              subject: 'MA',
              weekday: day,
              hour: 9,
              from: first,
              until: first.add(const Duration(days: 7)),
            ),
        ],
      );
      final plan = Scenario(
        id: '1',
        name: 'Monday off',
        from: first,
        until: first.add(const Duration(days: 3)),
        actions: {'r1:2026-10-05': PlanAction.miss},
      );
      final result = project(data, plan).single;
      expect(result.end.attended, 21);
      expect(result.end.held, 28);
      expect(result.end.eligible(), true);
      expect(result.dipsBelow, true);
      expect(result.lowest, 72);
      expect(data.subjects.single.official.held, 24);
    },
  );
  test(
    'two same-subject sessions, weights and cancelled classes are distinct',
    () {
      final date = DateTime(2026, 10, 5);
      final data = AppData(
        subjects: [const Subject('MA', 'Maths', Counts(18, 24), 0)],
        timetable: [
          TimetableRule(
            id: 'a',
            subject: 'MA',
            weekday: 1,
            hour: 9,
            weight: 2,
            from: date,
            until: date,
          ),
          TimetableRule(
            id: 'b',
            subject: 'MA',
            weekday: 1,
            hour: 11,
            from: date,
            until: date,
          ),
        ],
      );
      final plan = Scenario(
        id: '1',
        name: 'test',
        from: date,
        until: date,
        actions: {
          'a:2026-10-05': PlanAction.cancel,
          'b:2026-10-05': PlanAction.miss,
        },
      );
      expect(plannedSessions(data, plan).length, 2);
      expect(project(data, plan).single.end.held, 25);
      expect(project(data, plan).single.end.attended, 18);
    },
  );
}
