import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';

class FakePortal extends PortalService {
  AppData response = const AppData(
    subjects: [Subject('MA', 'Maths', Counts(18, 24), 0)],
    account: 'student1',
    semester: '2026',
  );
  bool fail = false;
  @override
  Future<AppData> fetchAttendance() async {
    if (fail) throw Exception('Offline');
    return response;
  }
}

void main() {
  test(
    'official sync preserves personal records and failed refresh preserves all data',
    () async {
      final portal = FakePortal();
      final app = AppController(AttendanceDatabase.memory(), portal);
      addTearDown(app.dispose);
      await app.initialize();
      await app.sync();
      await app.mark(
        Session(id: 'p', subject: 'MA', starts: DateTime(2026, 10, 1)),
        AttendanceStatus.present,
        'My note',
      );
      portal.response = portal.response.copyWith(
        subjects: [const Subject('MA', 'Maths', Counts(19, 25), 0)],
      );
      await app.sync();
      await app.sync();
      expect(app.data.personalLog('MA').held, 1);
      expect(app.data.sessions.single.note, 'My note');
      expect(app.data.subjects.single.official.held, 25);
      portal.fail = true;
      await expectLater(app.sync(), throwsException);
      expect(app.data.subjects.single.official.held, 25);
      expect(app.data.sessions.length, 1);
      portal.fail = false;
      portal.response = portal.response.copyWith(account: 'student2');
      await app.sync();
      expect(app.data.sessions, isEmpty);
    },
  );
}
