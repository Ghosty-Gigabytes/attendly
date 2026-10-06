import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/data/platform_service.dart';

Session entry(String date, AttendanceStatus status, {int weight = 1}) =>
    Session(
      id: '$date-${status.name}',
      subject: 'A',
      starts: DateTime.parse(date),
      status: status,
      weight: weight,
    );
AppData example({
  List<OfficialDay> days = const [],
  List<Session> logs = const [],
  Counts official = const Counts(15, 20),
}) => AppData(
  account: 'student',
  semester: 'semester',
  synced: DateTime(2026, 10, 6),
  subjects: [Subject('A', 'Algebra', official, 0)],
  officialDays: days,
  sessions: logs,
);
void main() {
  test('personal edits reload newer background official totals before saving', () async {
    final db = AttendanceDatabase.memory();
    final c = AppController(db, PortalService());
    addTearDown(c.dispose);
    c.scope = 'student:semester'; c.data = example();
    await db.save(c.scope, example(official: const Counts(16,21)));
    await c.logClasses('A', DateTime(2026,10,1), 1, 0);
    expect(c.data.subjects.single.official.attended, 16);
    expect(c.data.personal('A').attended,17);
    expect((await db.load(c.scope))!.sessions.length,1);
  });
  test('combined adds only personal dates absent or blank in IMS', () {
    final d = example(
      days: const [
        OfficialDay('A', '2026-10-01', '1+0'),
        OfficialDay('A', '2026-10-02', ''),
      ],
      logs: [
        entry('2026-10-01', AttendanceStatus.present, weight: 2),
        entry('2026-10-02', AttendanceStatus.present),
        entry('2026-10-03', AttendanceStatus.absent),
      ],
    );
    expect(d.personal('A').attended, 16);
    expect(d.personal('A').held, 22);
    expect(d.discrepancies.length, 1);
    expect(d.discrepancies.single.date, '2026-10-01');
    expect(d.subjects.single.official.held, 20);
  });
  test(
    'matching official upload replaces pending personal counts without doubling',
    () {
      final before = example(
        logs: [entry('2026-10-02', AttendanceStatus.present)],
      );
      final after = before.copyWith(
        subjects: const [Subject('A', 'Algebra', Counts(16, 21), 0)],
        officialDays: const [OfficialDay('A', '2026-10-02', '1')],
      );
      expect(before.personal('A').held, 21);
      expect(after.personal('A').held, 21);
      expect(after.personal('A').attended, 16);
      expect(after.discrepancies, isEmpty);
    },
  );
  test(
    'off-day and partial uploads retain official precedence and flag differences',
    () {
      final d = example(
        days: const [
          OfficialDay('A', '2026-10-01', 'GH'),
          OfficialDay('A', '2026-10-02', '1'),
        ],
        logs: [
          entry('2026-10-01', AttendanceStatus.present),
          entry('2026-10-02', AttendanceStatus.present, weight: 2),
        ],
      );
      expect(d.personal('A').held, 20);
      expect(d.discrepancies.length, 2);
    },
  );
  test(
    'unknown personal marks and cancelled sessions add no counted classes',
    () {
      final d = example(
        logs: [
          entry('2026-10-01', AttendanceStatus.unknown),
          entry('2026-10-02', AttendanceStatus.cancelled),
        ],
      );
      expect(d.personal('A').held, 20);
      expect(d.discrepancies, isEmpty);
    },
  );
  test('notification events distinguish unchanged, uploads and conflicts', () {
    final old = example(official: const Counts(10, 20));
    final same = PlatformService.publication(old, previous: old);
    final alerts = same['alerts'] as List;
    expect(alerts.where((a) => a['type'] == 'updates'), isEmpty);
    expect(alerts.where((a) => a['type'] == 'low').length, 1);
    final next = old.copyWith(
      officialDays: const [OfficialDay('A', '2026-10-01', '0')],
      sessions: [entry('2026-10-01', AttendanceStatus.present)],
    );
    final changed =
        PlatformService.publication(next, previous: old)['alerts'] as List;
    expect(
      changed.map((a) => a['type']),
      containsAll(['updates', 'low', 'discrepancies']),
    );
    expect(
      PlatformService.publication(next)['alerts'] as List,
      isNot(contains(predicate((dynamic a) => a['type'] == 'updates'))),
    );
    final resolved =
        PlatformService.publication(
              example(official: const Counts(19, 20)),
            )['clear']
            as List;
    expect(resolved, containsAll(['low', 'discrepancies']));
  });
}
