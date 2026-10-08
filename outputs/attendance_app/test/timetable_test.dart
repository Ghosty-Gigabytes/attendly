import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/domain/timetable.dart';

void main() {
  const subjects = [
    Subject('CS101', 'Computer Science', Counts(0, 0), 0),
    Subject('MA101', 'Mathematics', Counts(0, 0), 1),
  ];
  test(
    'CSV accepts quoted cells, BOM, CRLF, fences, reordered headers and abbreviated days',
    () {
      final rows = importTimetableCsv(
        '\uFEFF```csv\nsubject_code,day,end_time,attendance_count,start_time\r\n"cs101",mon,10:00,1,09:00\r\n```',
        subjects,
      );
      expect(rows.single.subject, 'CS101');
      expect(rows.single.weekday, 1);
      expect(rows.single.issues(subjects), isEmpty);
    },
  );
  test('unknown and incomplete cells stay available for correction', () {
    final rows = importTimetableCsv(
      '$timetableHeader\nTuesday,"Unknown, elective",,11:00,\nWednesday,MA101,12:00,13:00,1',
      subjects,
    );
    expect(rows.length, 2);
    expect(rows.first.subject, 'Unknown, elective');
    expect(rows.first.issues(subjects).length, 3);
  });
  test('malformed quoting or column counts fail without partial import', () {
    for (final value in [
      '$timetableHeader\nMonday,CS101,09:00,10:00,1\nTuesday,MA101',
      '$timetableHeader\n"Monday,CS101,09:00,10:00,1',
      'day,day,start_time,end_time,attendance_count\nMonday,CS101,09:00,10:00,1',
    ]) {
      expect(() => importTimetableCsv(value, subjects), throwsFormatException);
    }
  });
  test('time and weight validation do not infer class count from duration', () {
    final rows = importTimetableCsv(
      '$timetableHeader\nMonday,CS101,14:00,16:00,1\nTuesday,CS101,16:00,14:00,0',
      subjects,
    );
    expect(rows.first.rule(DateTime(2026), DateTime(2027)).weight, 1);
    expect(rows.last.issues(subjects).length, 2);
    expect(clockMinutes('24:00'), isNull);
    expect(clockMinutes('24:00', end: true), 1440);
  });
  test(
    'duplicates and overlapping subjects are flagged; touching sessions are allowed',
    () {
      final rows = importTimetableCsv(
        '$timetableHeader\nMonday,CS101,09:00,10:00,1\nMonday,CS101,09:00,10:00,1\nMonday,MA101,09:30,10:30,1\nMonday,CS101,10:30,11:30,1',
        subjects,
      );
      final issues = timetableIssues(rows, subjects);
      expect(issues[rows[0].id], contains('Duplicate class — remove one copy'));
      expect(issues[rows[2].id], isNotEmpty);
      expect(issues[rows[3].id], isEmpty);
    },
  );
  test('replacement preserves dates before and after its interval', () {
    final old = TimetableRule(
      id: 'old',
      subject: 'CS101',
      weekday: 1,
      hour: 9,
      from: DateTime(2026, 7, 1),
      until: DateTime(2026, 12, 31),
      endMinuteOfDay: 600,
    );
    final next = importTimetableCsv(
      '$timetableHeader\nTuesday,MA101,10:00,12:00,1',
      subjects,
    );
    final rules = replaceTimetableWindow(
      [old],
      next,
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
    );
    expect(rules.length, 3);
    expect(rules[0].until, DateTime(2026, 9, 30));
    expect(rules[1].from, DateTime(2026, 11, 1));
    expect(rules.where((r) => r.on(DateTime(2026, 10, 5)) != null), isEmpty);
    expect(
      rules.where((r) => r.on(DateTime(2026, 10, 6)) != null).single.subject,
      'MA101',
    );
  });
  test(
    'old persisted schedules remain readable and new end times round trip',
    () {
      final old = {
        'id': 'old',
        'subject': 'CS101',
        'weekday': 1,
        'hour': 9,
        'minute': 0,
        'weight': 1,
        'from': '2026-07-01',
        'until': '2026-12-31',
      };
      expect(TimetableRule.fromJson(old).endMinutes, 600);
      final rule = TimetableRule.fromJson({...old, 'endMinuteOfDay': 660});
      expect(TimetableRule.fromJson(rule.toJson()).endMinutes, 660);
    },
  );
  test(
    'AI prompt contains actual subjects, section and conservative counting instruction',
    () {
      final prompt = timetableAiPrompt(subjects, 'ECE A / batch 2');
      expect(prompt, contains('CS101 — Computer Science'));
      expect(prompt, contains('ECE A / batch 2'));
      expect(prompt, contains('Do not infer it from duration'));
    },
  );
}
