import 'package:attendly/domain/models.dart';

AppData sampleData(DateTime now) {
  final today = dayOnly(now);
  final from = DateTime(today.year, today.month, today.day - 42);
  final until = DateTime(today.year, today.month, today.day + 90);
  const subjects = [
    Subject('MA201', 'Engineering Mathematics', Counts(24, 32), 0xFF5268DA),
    Subject('CS201', 'Data Structures', Counts(29, 34), 0xFF118E80),
    Subject('EC201', 'Digital Electronics', Counts(21, 30), 0xFFD28B37),
    Subject('HS201', 'Technical Communication', Counts(18, 22), 0xFF9662CD),
    Subject('CS203', 'Object Oriented Programming', Counts(25, 30), 0xFFCC6381),
  ];
  final timetable = <TimetableRule>[];
  const week = [
    [0, 1, 2],
    [1, 3, 4],
    [0, 2, 4],
    [1, 2, 3],
    [0, 1, 4],
  ];
  for (var day = 1; day <= 5; day++) {
    for (var slot = 0; slot < 3; slot++) {
      timetable.add(
        TimetableRule(
          id: 'demo-$day-$slot',
          subject: subjects[week[day - 1][slot]].code,
          weekday: day,
          hour: 9 + slot * 2,
          from: from,
          until: until,
        ),
      );
    }
  }
  final sessions = <Session>[], officialDays = <OfficialDay>[];
  var index = 0;
  for (
    var day = from;
    day.isBefore(today);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    for (final rule in timetable) {
      final s = rule.on(day);
      if (s == null) continue;
      final status = index % 7 == 0
          ? AttendanceStatus.absent
          : AttendanceStatus.present;
      sessions.add(s.mark(status, ''));
      if (day.isBefore(today.subtract(const Duration(days: 3)))) {
        officialDays.add(
          OfficialDay(s.subject, dateKey(day), index % 9 == 0 ? 'A' : 'P'),
        );
      }
      index++;
    }
  }
  return AppData(
    subjects: subjects,
    officialDays: officialDays,
    sessions: sessions,
    timetable: timetable,
    account: 'Demo student',
    semester: 'Sample semester',
    synced: now.subtract(const Duration(hours: 3)),
    showPersonal: false,
  );
}
