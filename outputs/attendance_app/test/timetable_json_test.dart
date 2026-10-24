import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/domain/timetable.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/domain/display_dates.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/data/platform_service.dart';

void main() {
  const subjects = [Subject('DC101', 'Digital Communication', Counts(0, 0), 0)];
  Map<String, dynamic> session() => {
    'day': 'Monday',
    'subject_code': 'DC101',
    'subject_label': 'LAB DC G2',
    'kind': 'lab',
    'group': 'G2',
    'start_time': '14:00',
    'end_time': '16:00',
    'attendance_count': null,
  };
  String document(Map<String, dynamic> row) => jsonEncode({
    'version': 1,
    'group': 'G2',
    'sessions': [row],
  });
  test(
    'JSON preserves uncertain lab counts and original labels for review',
    () {
      final row = importTimetable(
        '```json\n${document(session())}\n```',
        subjects,
      ).single;
      expect(row.sourceLabel, 'LAB DC G2');
      expect(row.kind, 'lab');
      expect(row.count, '');
      expect(row.issues(subjects), contains('Attendance count must be 1–20'));
      final corrected = row.copy(count: '1');
      final rule = corrected.rule(DateTime(2026), DateTime(2027));
      final roundtrip = TimetableEntry.fromRule(
        TimetableRule.fromJson(rule.toJson()),
      );
      expect(roundtrip.sourceLabel, row.sourceLabel);
      expect(roundtrip.group, 'G2');
      expect(roundtrip.endMinutes, 960);
      expect(roundtrip.issues(subjects), isEmpty);
    },
  );
  test(
    'unknown subjects are never guessed and weekend rows require correction',
    () {
      final row = importTimetable(
        document({
          ...session(),
          'subject_code': null,
          'subject_label': 'ITSA TUT',
          'day': 'Saturday',
        }),
        subjects,
      ).single;
      expect(row.subject, isEmpty);
      expect(row.sourceLabel, 'ITSA TUT');
      expect(
        row.issues(subjects),
        containsAll(['Match a subject', 'Choose Monday to Friday']),
      );
      expect(weekdays.length, 5);
    },
  );
  test(
    'wrong groups, malformed JSON and incorrect types cannot partially import',
    () {
      for (final value in [
        document({...session(), 'group': 'G1'}),
        document({...session(), 'attendance_count': '2'}),
        '{"version":2,"sessions":[]}',
        document({...session(), 'start_time': 14}),
      ]) {
        expect(() => importTimetable(value, subjects), throwsFormatException);
      }
    },
  );
  test('12 hour formatting and parsing handles noon and midnight', () {
    expect(displayClock(0, use24Hour: false), '12:00 AM');
    expect(displayClock(720, use24Hour: false), '12:00 PM');
    expect(displayClock(840, use24Hour: false), '2:00 PM');
    expect(displayClock(840), '14:00');
    expect(parseDisplayClock('12:00 AM'), 0);
    expect(parseDisplayClock('12:00 pm'), 720);
    expect(parseDisplayClock('2:35 PM'), 875);
    expect(parseDisplayClock('14:35'), 875);
    expect(parseDisplayClock('14:35 PM'), isNull);
    expect(parseDisplayClock('12:60 AM'), isNull);
  });
  test('time format persists and formats widget refresh time', () async {
    final controller = AppController(
      AttendanceDatabase.memory(),
      PortalService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.setTimeFormat('12');
    await controller.initialize();
    expect(controller.use24Hour, false);
    expect(controller.platform.use24Hour, false);
    final data = AppData(synced: DateTime(2026, 10, 9, 14, 35));
    final widget = jsonDecode(
      PlatformService.publication(data, use24Hour: false)['widget'] as String,
    );
    expect(widget['updated'], contains('2:35 PM'));
    await controller.setTimeFormat('24');
    expect(controller.use24Hour, true);
  });
}
