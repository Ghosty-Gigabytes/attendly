import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/portal_service.dart';

void main() {
  test('rapid edits to different sessions are both retained', () async {
    final controller = AppController(
      AttendanceDatabase.memory(),
      PortalService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.scope = 'test-student:semester';
    controller.authenticated = true;
    final date = DateTime(2026, 10, 1);
    await Future.wait([
      controller.mark(
        Session(id: 'a', subject: 'MA', starts: date),
        AttendanceStatus.present,
        '',
      ),
      controller.mark(
        Session(id: 'b', subject: 'MA', starts: date),
        AttendanceStatus.absent,
        '',
      ),
      controller.showPersonal(true),
    ]);
    expect(controller.data.sessions.length, 2);
    expect(controller.data.personalLog('MA').held, 2);
    expect(controller.data.personalLog('MA').attended, 1);
    expect(controller.data.subjects, isEmpty);
  });
  test(
    'scoped persistence separates accounts, records and repeat snapshots',
    () async {
      final db = AttendanceDatabase.memory();
      addTearDown(db.close);
      final source = AppData(
        subjects: [const Subject('MA', 'Maths', Counts(18, 24), 0)],
        sessions: [
          Session(
            id: 's1',
            subject: 'MA',
            starts: DateTime(2026, 10, 1),
            status: AttendanceStatus.present,
          ),
        ],
      );
      await db.save('demo', source);
      await db.save('demo', source);
      await db.save('real:semester', const AppData());
      final loaded = (await db.load('demo'))!;
      expect(loaded.sessions.length, 1);
      expect(loaded.personalLog('MA').held, 1);
      expect(loaded.subjects.single.official.held, 24);
      expect((await db.load('real:semester'))!.subjects, isEmpty);
    },
  );
}
