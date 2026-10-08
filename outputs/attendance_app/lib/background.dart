import 'domain/display_dates.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'data/captcha_service.dart';
import 'data/credential_store.dart';
import 'data/database.dart';
import 'data/platform_service.dart';
import 'data/portal_service.dart';
import 'data/portal_parser.dart';
import 'domain/models.dart';

Future<void> runBackgroundRefresh() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = PlatformService(),
      credentials = CredentialStore(),
      portal = PortalService();
  AttendanceDatabase? db;
  bool success = false;
  try {
    db = await AttendanceDatabase.open();
    final database = db;
    final epoch = await database.dataEpoch;
    final login = await credentials.read();
    if (login == null) {
      success = true;
      return;
    }
    final challenge = await portal.challenge();
    final answer = await CaptchaService().recognize(challenge.image);
    if (answer == null) {
      throw const PortalLoginRejected('Manual CAPTCHA needed');
    }
    await portal.login(challenge, login.username, login.password, answer);
    final fresh = await portal.fetchAttendance();
    // Do not publish a stale account after a foreground sign-out/account switch.
    final current = await credentials.read();
    if (current == null ||
        current.username != login.username ||
        current.password != login.password) {
      success = true;
      return;
    }
    final scope = '${fresh.account}:${fresh.semester}';
    AppData? previous;
    AppData? merged;
    await database.transaction(() async {
      if (await database.dataEpoch != epoch) return;
      final saved = await credentials.read();
      if (saved == null ||
          saved.username != login.username ||
          saved.password != login.password) {
        return;
      }
      previous = await database.load(scope);
      merged = (previous ?? const AppData()).copyWith(
        subjects: fresh.subjects,
        officialDays: fresh.officialDays,
        account: fresh.account,
        semester: fresh.semester,
        synced: fresh.synced,
      );
      await database.save(scope, merged!);
      await database.setPreference('active', scope);
    });
    if (merged == null) {
      success = true;
      return;
    }
    await platform.publish(merged!, previous: previous);
    await platform.status('Refreshed ${displayDateTime(DateTime.now())}');
    success = true;
  } on PortalLoginRejected {
    await platform.status('Open Attendly to complete IMS sign-in.');
    await PlatformService.channel.invokeMethod('publish', {
      'alerts': [
        {
          'type': 'auth',
          'title': 'Attendance refresh needs sign-in',
          'body': 'Open Attendly to complete the IMS CAPTCHA.',
          'fingerprint': 'manual-sign-in',
        },
      ],
      'clear': [],
    });
    success = true;
  } on PortalSessionExpired {
    await platform.status('IMS session expired. Open Attendly to sign in.');
    success = true;
  } catch (_) {
    try {
      await platform.status(
        'Refresh failed at ${displayDateTime(DateTime.now())}. Android will retry.',
      );
    } catch (_) {}
  } finally {
    portal.dio.close();
    if (db != null) await db.close();
    await const MethodChannel(
      'dev.attendly/background',
    ).invokeMethod('complete', {'success': success});
  }
}
