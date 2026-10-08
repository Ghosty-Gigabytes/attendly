import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/data/portal_parser.dart';
import 'package:attendly/data/credential_store.dart';
import 'package:attendly/domain/models.dart';
import 'support/fake_login.dart';

class StartupPortal extends PortalService {
  int logins = 0;
  bool offline = false, reject = false, badReport = false;
  @override
  Future<LoginChallenge> challenge() async {
    if (offline) throw Exception('No internet');
    return LoginChallenge(PortalForm(Uri.parse('https://example.test'), {}, null), Uint8List(0));
  }
  @override
  Future<void> login(LoginChallenge c, String u, String p, String answer) async {
    logins++;
    if (reject) throw const PortalLoginRejected('Rejected');
  }
  @override
  Future<AppData> fetchAttendance() async {
    if (badReport) throw const PortalException('Changed report');
    return AppData(account: 'student', semester: 'semester', synced: DateTime(2026,10,7), subjects: const [Subject('A','Algebra',Counts(8,10),0)]);
  }
}
void main() {
  Future<AppController> setup(StartupPortal portal) async {
    final db = AttendanceDatabase.memory();
    await db.save('student:semester', AppData(account:'student',semester:'semester',synced:DateTime(2026,10,6),subjects:const [Subject('A','Algebra',Counts(7,10),0)]));
    await db.setPreference('active','student:semester');
    final app = AppController(db,portal,credentials:MemoryCredentials(const SavedLogin('student','password')),captchaService:FixedCaptcha('1234'),retryDelay:Duration.zero);
    await app.initialize();
    addTearDown(app.dispose);
    return app;
  }
  test('cached records open before any network call and survive offline refresh', () async {
    final portal = StartupPortal()..offline=true;
    final app = await setup(portal);
    expect(app.authenticated,true);
    expect(portal.logins,0);
    await app.refreshInBackground();
    expect(app.authenticated,true);
    expect(app.loginFailures,0);
    expect(app.data.subjects.single.official.attended,7);
  });
  test('five rejected attempts require login without deleting cached records', () async {
    final portal = StartupPortal()..reject=true;
    final app = await setup(portal);
    await app.refreshInBackground();
    expect(portal.logins,5);
    expect(app.loginRequired,true);
    expect(app.authenticated,false);
    expect(app.data.subjects.single.official.attended,7);
    await app.initialize();
    expect(app.loginRequired,true);
    await app.refreshInBackground();
    expect(portal.logins,5);
  });
  test('successful refresh replaces official counts', () async {
    final app = await setup(StartupPortal());
    await app.refreshInBackground();
    expect(app.authenticated,true);
    expect(app.loginFailures,0);
    expect(app.data.subjects.single.official.attended,8);
  });
  test('parser failures preserve cache and never count as login failures', () async {
    final app = await setup(StartupPortal()..badReport=true);
    await app.refreshInBackground();
    expect(app.authenticated,true);
    expect(app.loginFailures,0);
    expect(app.data.subjects.single.official.attended,7);
  });
  test('signing out prevents cached account from reopening', () async {
    final app = await setup(StartupPortal());
    await app.logout();
    await app.initialize();
    expect(app.authenticated,false);
    expect(app.scope,isEmpty);
  });
}
