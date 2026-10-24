import 'dart:convert';
import '../domain/student_id.dart';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import 'database.dart';
import 'credential_store.dart';
import 'captcha_service.dart';
import 'portal_service.dart';
import 'portal_parser.dart';
import 'platform_service.dart';
import 'system_accent.dart';

class AppController extends ChangeNotifier {
  final AttendanceDatabase db;
  final PortalService portal;
  AppData data = const AppData();
  String themePreference = 'system';
  String timeFormat = '24';
  bool get use24Hour => timeFormat == '24';
  Future<void> setTimeFormat(String value) async {
    if (!{'12', '24'}.contains(value) || deletingLocalData) return;
    final generation = _generation;
    await _enqueue(() async {
      if (generation != _generation || deletingLocalData) return;
      await db.setPreference('timeFormat', value);
      timeFormat = value;
      platform.use24Hour = use24Hour;
      if (!_disposed) notifyListeners();
      await platform.refreshWidget(data);
    });
  }

  String palettePreference = 'material';
  String materialAccent = 'system';
  int? systemAccent;
  int get materialSeed => materialAccent == 'system'
      ? systemAccent ?? 0xFF2463BC
      : 0xFF000000 | (int.tryParse(materialAccent, radix: 16) ?? 0x2463BC);
  Future<void> refreshWidgetAppearance() async {
    if (_disposed || deletingLocalData) return;
    platform.themeMode = themePreference;
    platform.accentSeed = materialSeed;
    await db.setPreference('widgetAccentSeed', '$materialSeed');
    if (!_disposed && !deletingLocalData) await platform.refreshWidget(data);
  }

  Future<void> setMaterialAccent(String value) async {
    if (value != 'system' && !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) {
      return;
    }
    materialAccent = value == 'system' ? value : value.toUpperCase();
    await db.setPreference('materialAccent', materialAccent);
    if (materialAccent == 'system') await refreshSystemAccent();
    if (!_disposed) notifyListeners();
    await refreshWidgetAppearance();
  }

  Future<void> refreshSystemAccent() async {
    final next = await readSystemAccent();
    if (_disposed) return;
    if (next != systemAccent) {
      systemAccent = next;
      notifyListeners();
      await refreshWidgetAppearance();
    }
  }

  Future<void> setPalette(String value) async {
    if (!{'classic', 'bauhaus', 'material'}.contains(value)) return;
    await db.setPreference('palette', value);
    palettePreference = value;
    notifyListeners();
  }

  Future<void> setTheme(String value) async {
    await db.setPreference('theme', value);
    themePreference = value;
    notifyListeners();
    await refreshWidgetAppearance();
  }

  String scope = '';
  bool authenticated = false;
  bool loginRequired = false;
  bool _sessionReady = false;
  bool _restoring = false;
  bool _disposed = false;
  int loginFailures = 0;
  bool deletingLocalData = false;
  bool get refreshing => busy || _restoring || deletingLocalData;
  bool get hasLiveSession => _sessionReady;
  int _generation = 0;
  bool busy = false;
  String? error;
  Future<void> _writes = Future.value();
  final PlatformService platform;
  final CredentialStore credentials;
  final CaptchaService captchaService;
  final Duration retryDelay;
  final Future<int?> Function() readSystemAccent;
  AppController(
    this.db,
    this.portal, {
    CredentialStore? credentials,
    CaptchaService? captchaService,
    PlatformService? platform,
    this.retryDelay = const Duration(seconds: 1),
    Future<int?> Function()? systemAccentReader,
  }) : platform = platform ?? PlatformService(),
       readSystemAccent = systemAccentReader ?? SystemAccent.read,
       credentials = credentials ?? CredentialStore(),
       captchaService = captchaService ?? CaptchaService();
  Future<void> initialize({bool deferPlatformWork = false}) async {
    timeFormat = await db.preference('timeFormat') == '12' ? '12' : '24';
    platform.use24Hour = use24Hour;
    themePreference = await db.preference('theme') ?? 'system';
    final savedPalette = await db.preference('palette');
    palettePreference =
        {'classic', 'bauhaus', 'material'}.contains(savedPalette)
        ? savedPalette!
        : 'material';
    final savedAccent = await db.preference('materialAccent');
    materialAccent =
        savedAccent == 'system' ||
            RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(savedAccent ?? '')
        ? savedAccent!
        : 'system';
    if (!deferPlatformWork) await refreshSystemAccent();
    scope = '';
    data = const AppData();
    authenticated = false;
    _sessionReady = false;
    loginRequired = false;
    loginFailures = 0;
    final active = await db.preference('active');
    if (active != null &&
        active.isNotEmpty &&
        active != 'demo' &&
        !active.startsWith('personal:')) {
      final cached = await db.load(active);
      if (cached != null &&
          cached.account.isNotEmpty &&
          cached.synced != null) {
        scope = active;
        data = cached;
        loginFailures =
            int.tryParse(
              await db.preference('loginFailures:${cached.account}') ?? '',
            ) ??
            0;
        loginRequired = loginFailures >= 5;
        authenticated = !loginRequired;
      }
    }
    notifyListeners();
    if (!deferPlatformWork) await refreshWidgetAppearance();
  }

  Future<void> prepareStartupTheme() async {
    if (materialAccent != 'system') return;
    try {
      systemAccent = await readSystemAccent().timeout(
        const Duration(seconds: 1),
      );
    } catch (_) {
      // Use the material fallback if the OS colour service is unavailable.
    }
  }

  Future<void> finishStartupAppearance() async {
    try {
      await refreshWidgetAppearance();
    } catch (_) {
      // Optional platform work must not prevent cached attendance from opening.
    }
  }

  /// Open cached records first; a fresh portal session is established quietly.
  Future<void> refreshInBackground() async {
    if (_disposed || refreshing || loginRequired || !authenticated) return;
    if (_sessionReady) {
      try {
        await sync();
      } catch (_) {}
      if (_sessionReady || _disposed || !authenticated) return;
    }
    _restoring = true;
    error = null;
    final generation = _generation;
    notifyListeners();
    try {
      final saved = await credentials.read();
      if (saved == null || saved.username.trim() != data.account) {
        error =
            'Saved attendance is available. Sign out and sign in again from Settings to refresh it.';
        return;
      }
      while (loginFailures < 5 && generation == _generation && !_disposed) {
        try {
          final challenge = await portal.challenge();
          final answer = await captchaService.recognize(challenge.image);
          if (generation != _generation || _disposed) return;
          if (answer == null || answer.trim().isEmpty) {
            throw const PortalLoginRejected(
              'Could not read the login security number.',
            );
          }
          await portal.login(challenge, saved.username, saved.password, answer);
          if (generation != _generation || _disposed) return;
          _sessionReady = true;
          loginFailures = 0;
          await db.setPreference('loginFailures:${data.account}', '0');
          // Leave retry mode before importing; parser/network errors are not login failures.
          _restoring = false;
          try {
            await sync();
          } catch (_) {}
          return;
        } on PortalLoginRejected {
          if (generation != _generation || _disposed) return;
          loginFailures++;
          await db.setPreference(
            'loginFailures:${data.account}',
            '$loginFailures',
          );
          if (loginFailures < 5) {
            await Future<void>.delayed(retryDelay * loginFailures);
          }
        }
      }
      if (generation == _generation && !_disposed && loginFailures >= 5) {
        loginRequired = true;
        authenticated = false;
        error =
            'Automatic sign-in failed 5 times. Please sign in again. Your saved records are still on this device.';
      }
    } catch (_) {
      if (generation == _generation && !_disposed) {
        error =
            'Could not refresh right now. You can keep viewing your saved attendance and try again later.';
      }
    } finally {
      _restoring = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> signIn(
    LoginChallenge challenge,
    String username,
    String password,
    String captcha,
  ) async {
    if (deletingLocalData) return;
    final generation = _generation;
    await portal.login(challenge, username, password, captcha);
    if (generation != _generation || _disposed) return;
    _sessionReady = true;
    loginRequired = false;
    loginFailures = 0;
    await db.setPreference('loginFailures:${username.trim()}', '0');
    String? storageWarning;
    try {
      final saved = await credentials.read();
      if (generation != _generation || _disposed) return;
      if (saved != null && saved.username != username.trim()) {
        await platform.clear();
      }
      if (generation != _generation || _disposed) return;
      await credentials.write(username.trim(), password);
    } catch (_) {
      storageWarning =
          'Signed in, but your login could not be saved securely. You may need to sign in again next time.';
    }
    if (generation != _generation || _disposed) return;
    final oldScope = await db.preference('active');
    final old = oldScope == null ? null : await db.load(oldScope);
    if (generation != _generation || _disposed) return;
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
    if (generation != _generation || _disposed) return;
    try {
      await sync();
    } on PortalSessionExpired {
      rethrow;
    } catch (_) {
      // An attendance-layout/network failure after confirmed login is not an
      // authentication failure. Show only this user's records and sync error.
      if (generation != _generation || _disposed) return;
      authenticated = true;
      notifyListeners();
    }
    if (generation != _generation || _disposed) return;
    if (storageWarning != null) {
      error = error == null ? storageWarning : '$error\n$storageWarning';
      notifyListeners();
    }
  }

  Future<StudentIdData?> cachedIdCard() async {
    if (!authenticated || data.account.isEmpty) return null;
    final owner = data.account;
    final raw = await db.preference('idCard:$owner');
    if (!authenticated || data.account != owner || raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final card = StudentIdData.fromJson(jsonDecode(raw));
      return card.rollNumber.toUpperCase() == owner.toUpperCase() ? card : null;
    } catch (_) {
      return null;
    }
  }

  Future<StudentIdData> fetchIdCard() async {
    final owner = data.account;
    final generation = _generation;
    if (!authenticated || owner.isEmpty || deletingLocalData) {
      throw const PortalSessionExpired();
    }
    bool current() =>
        !_disposed &&
        !deletingLocalData &&
        generation == _generation &&
        data.account == owner &&
        authenticated;
    // Reuse the existing login task instead of starting a competing CAPTCHA flow.
    for (
      var attempts = 0;
      (busy || _restoring) && attempts < 450 && current();
      attempts++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!current()) throw const PortalSessionExpired();
    if (busy || _restoring) {
      throw const PortalException(
        'IMS is still refreshing. Please try loading the ID card again shortly.',
      );
    }
    if (!_sessionReady) await refreshInBackground();
    if (!current() || !_sessionReady) throw const PortalSessionExpired();
    StudentIdData card;
    try {
      card = await portal.fetchIdCard();
    } on PortalSessionExpired {
      _sessionReady = false;
      await refreshInBackground();
      if (!current() || !_sessionReady) rethrow;
      card = await portal.fetchIdCard();
    }
    if (!current()) throw const PortalSessionExpired();
    await _enqueue(() async {
      if (!current()) throw const PortalSessionExpired();
      await db.setPreference('idCard:$owner', jsonEncode(card.toJson()));
    });
    if (!current()) throw const PortalSessionExpired();
    return card;
  }

  Future<void> mutate(AppData Function(AppData) change) async {
    if (deletingLocalData) return;
    final generation = _generation;
    final saveScope = scope;
    // Compute inside the queue so rapid edits cannot overwrite one another.
    await _enqueue(() async {
      if (scope != saveScope || generation != _generation) return;
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

  Future<void> saveTimetableDraft(String value) {
    final generation = _generation;
    final savedScope = scope;
    return _enqueue(() async {
      if (deletingLocalData ||
          generation != _generation ||
          scope != savedScope ||
          scope.isEmpty) {
        return;
      }
      await db.setPreference('timetableDraft:$scope', value);
    });
  }

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
  Future<void> deleteAllLocalData() async {
    if (deletingLocalData) return;
    deletingLocalData = true;
    _generation++;
    _sessionReady = false;
    notifyListeners();
    try {
      await credentials.clear();
      await platform.deleteLocalData();
      await portal.logout();
      await _enqueue(() async {
        await db.deleteAllLocalData();
        scope = '';
        data = const AppData();
        authenticated = false;
        loginRequired = false;
        loginFailures = 0;
        themePreference = 'system';
        timeFormat = '24';
        platform.use24Hour = true;
        platform.themeMode = 'system';
        platform.accentSeed = 0xFF2463BC;
        palettePreference = 'material';
        materialAccent = 'system';
        error = null;
      });
    } catch (_) {
      throw StateError(
        'Could not finish deleting local data. Please try again.',
      );
    } finally {
      deletingLocalData = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> logout() async {
    _generation++;
    _sessionReady = false;
    loginRequired = false;
    loginFailures = 0;
    await _enqueue(() async {
      await db.setPreference('active', '');
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
    if (_restoring || deletingLocalData) return;
    if (!_sessionReady && authenticated && data.synced != null) {
      await refreshInBackground();
      return;
    }
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    final generation = _generation;
    try {
      final fresh = await portal.fetchAttendance();
      if (generation != _generation || _disposed) return;
      _sessionReady = true;
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
      if (generation != _generation || _disposed) return;
      error = e.toString();
      if (e is PortalSessionExpired) {
        _sessionReady = false;
        // Cached records remain visible while saved-login retries run.
        if (data.synced == null) authenticated = false;
      }
      rethrow;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
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
    _disposed = true;
    _generation++;
    db.close();
    portal.dio.close();
    super.dispose();
  }
}

