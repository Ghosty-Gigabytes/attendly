import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import 'database.dart';
import 'credential_store.dart';
import 'captcha_service.dart';
import 'portal_service.dart';
import 'portal_parser.dart';
import 'platform_service.dart';

class AppController extends ChangeNotifier {
  final AttendanceDatabase db;
  final PortalService portal;
  AppData data = const AppData();
  String themePreference = 'system';
  Future<void> setTheme(String value) async {
    await db.setPreference('theme', value);
    themePreference = value;
    notifyListeners();
  }

  String scope = '';
  bool authenticated = false;
  int _generation = 0;
  bool busy = false;
  String? error;
  Future<void> _writes = Future.value();
  final PlatformService platform = PlatformService();
  final CredentialStore credentials;
  final CaptchaService captchaService;
  AppController(
    this.db,
    this.portal, {
    CredentialStore? credentials,
    CaptchaService? captchaService,
  }) : credentials = credentials ?? CredentialStore(),
       captchaService = captchaService ?? CaptchaService();
  Future<void> initialize() async {
    themePreference = await db.preference('theme') ?? 'system';
    // Cookies are in-memory. A saved workspace is not evidence of an active
    // IMS login, and legacy demo/personal-only scopes must never unlock the app.
    scope = '';
    data = const AppData();
    authenticated = false;
    notifyListeners();
  }

  Future<void> signIn(
    LoginChallenge challenge,
    String username,
    String password,
    String captcha,
  ) async {
    await portal.login(challenge, username, password, captcha);
    String? storageWarning;
    try {
      final saved = await credentials.read();
      if (saved != null && saved.username != username.trim()) {
        await platform.clear();
      }
      await credentials.write(username.trim(), password);
    } catch (_) {
      storageWarning =
          'Signed in, but your login could not be saved securely. You may need to sign in again next time.';
    }
    final oldScope = await db.preference('active');
    final old = oldScope == null ? null : await db.load(oldScope);
    if (old != null &&
        old.account == username.trim() &&
        !oldScope!.startsWith('personal:') &&
        oldScope != 'demo') {
      scope = oldScope;
      data = old;
    } else {
      scope = '';
      data = AppData(account: username.trim());
    }
    try {
      await sync();
    } on PortalSessionExpired {
      rethrow;
    } catch (_) {
      // An attendance-layout/network failure after confirmed login is not an
      // authentication failure. Show only this user's records and sync error.
      authenticated = true;
      notifyListeners();
    }
    if (storageWarning != null) {
      error = error == null ? storageWarning : '$error\n$storageWarning';
      notifyListeners();
    }
  }

  Future<void> mutate(AppData Function(AppData) change) async {
    final saveScope = scope;
    // Compute inside the queue so rapid edits cannot overwrite one another.
    await _enqueue(() async {
      if (scope != saveScope) return;
      await db.transaction(() async {
        final latest = await db.load(saveScope) ?? data;
        final next = change(latest);
        await db.save(saveScope, next);
        data = next;
      });
      notifyListeners();
      await platform.publish(data);
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> update(AppData next) => mutate((_) => next);

  Future<void> showPersonal(bool value) =>
      mutate((current) => current.copyWith(showPersonal: value));
  Future<void> mark(
    Session session,
    AttendanceStatus status,
    String note,
  ) async {
    await mutate((current) {
      final sessions = [...current.sessions]
        ..removeWhere((s) => s.id == session.id);
      sessions.add(session.mark(status, note));
      return current.copyWith(sessions: sessions);
    });
  }

  Future<void> deletePersonalRecord(String id) => mutate(
    (current) => current.copyWith(
      sessions: current.sessions.where((s) => s.id != id).toList(),
    ),
  );

  Future<void> logClasses(
    String subject,
    DateTime day,
    int present,
    int absent,
  ) async {
    if (present < 0 ||
        absent < 0 ||
        present + absent == 0 ||
        dayOnly(day).isAfter(dayOnly(DateTime.now()))) {
      throw ArgumentError(
        'Choose a past or current date and at least one class.',
      );
    }
    final id = 'log-${DateTime.now().microsecondsSinceEpoch}';
    await mutate((current) {
      if (!current.subjects.any((s) => s.code == subject)) {
        throw ArgumentError('Select a subject from this semester.');
      }
      return current.copyWith(
        sessions: [
          ...current.sessions,
          if (present > 0)
            Session(
              id: '$id-present',
              subject: subject,
              starts: dayOnly(day),
              weight: present,
              status: AttendanceStatus.present,
            ),
          if (absent > 0)
            Session(
              id: '$id-absent',
              subject: subject,
              starts: dayOnly(day),
              weight: absent,
              status: AttendanceStatus.absent,
            ),
        ],
      );
    });
  }

  Future<void> saveScenario(Scenario scenario) async {
    await mutate((current) {
      final scenarios = [...current.scenarios]
        ..removeWhere((s) => s.id == scenario.id);
      scenarios.add(scenario);
      return current.copyWith(scenarios: scenarios);
    });
  }

  Future<void> deleteScenario(String id) => mutate(
    (current) => current.copyWith(
      scenarios: current.scenarios.where((s) => s.id != id).toList(),
    ),
  );
  Future<void> logout() async {
    _generation++;
    await _enqueue(() async {
      await credentials.clear();
      await platform.clear();
      await portal.logout();
      scope = '';
      data = const AppData();
      authenticated = false;
      error = null;
      notifyListeners();
    });
  }

  Future<void> sync() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    final generation = _generation;
    try {
      final fresh = await portal.fetchAttendance();
      await _enqueue(() async {
        if (generation != _generation) return;
        final nextScope = '${fresh.account}:${fresh.semester}';
        AppData? old;
        await db.transaction(() async {
          old = await db.load(nextScope) ?? (nextScope == scope ? data : null);
          final merged = (old ?? const AppData()).copyWith(
            subjects: fresh.subjects,
            officialDays: fresh.officialDays,
            account: fresh.account,
            semester: fresh.semester,
            synced: fresh.synced,
          );
          await db.save(nextScope, merged);
          await db.setPreference('active', nextScope);
          scope = nextScope;
          data = merged;
          authenticated = true;
        });
        await platform.publish(data, previous: old);
      });
    } catch (e) {
      error = e.toString();
      if (e is PortalSessionExpired) authenticated = false;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> reloadStored() async {
    if (!authenticated || busy || scope.isEmpty) return;
    await _enqueue(() async {
      final saved = await db.load(scope);
      if (saved != null && saved.account == data.account) {
        data = saved;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    db.close();
    portal.dio.close();
    super.dispose();
  }
}
