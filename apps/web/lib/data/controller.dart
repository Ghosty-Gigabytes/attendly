import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/student_id.dart';
import 'api.dart';
import 'store.dart';

class AppController extends ChangeNotifier {
  final Api api;
  final LocalStore db;
  AppController(this.api, this.db);
  AppData data = const AppData();
  StudentIdData? idCard;
  Map<String, dynamic>? user;
  String scope = '', theme = 'system', timeFormat = '24';
  int accent = 0xFF2463BC;
  bool ready = false,
      busy = false,
      refreshing = false,
      online = false,
      imsSessionReady = false,
      needsLogin = false;
  String? error;
  List<Map<String, dynamic>> pending = [];
  Map<String, Map<String, dynamic>> serverRecords = {};
  List<Map<String, dynamic>> conflicts = [];
  Future<void> _serial = Future.value();
  bool _disposed = false;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  String get _owner => user?['id'] as String? ?? '';
  bool get use24Hour => timeFormat == '24';
  String key(String kind, String id) => '$kind|$id';
  Future<void> initialize({bool connect = true}) async {
    theme = await db.preference('theme') ?? 'system';
    timeFormat = await db.preference('timeFormat') ?? '24';
    accent = int.tryParse(await db.preference('accent') ?? '') ?? accent;
    final saved = await db.read('current-user');
    if (saved is Map) {
      user = Map<String, dynamic>.from(saved);
      await _restore();
    }
    ready = true;
    changed();
    if (connect) unawaited(checkSession());
  }

  Future<void> _restore() async {
    final card = await db.read('id-card:$_owner');
    idCard = card is Map
        ? StudentIdData.fromJson(Map<String, dynamic>.from(card))
        : null;
    final saved = await db.read('account:$_owner');
    if (saved is Map) {
      data = AppData.fromJson(Map<String, dynamic>.from(saved['data'] as Map));
      scope = saved['scope'] as String;
      pending = (saved['pending'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      serverRecords = Map<String, dynamic>.from(
        saved['records'] as Map? ?? {},
      ).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    }
  }

  Future<void> _persist() async {
    if (_owner.isEmpty) return;
    await db.write('account:$_owner', {
      'data': data.toJson(),
      'scope': scope,
      'pending': pending,
      'records': serverRecords,
    });
  }

  Future<void> checkSession() async {
    try {
      final current = await api.get('/auth/me');
      if (user != null && user!['id'] != current['id']) {
        needsLogin = true;
        online = false;
        changed();
        return;
      }
      user = current;
      await db.write('current-user', current);
      if (scope.isEmpty) await _restore();
      online = true;
      needsLogin = false;
      await synchronize();
    } catch (e) {
      online = false;
      needsLogin = e is DioException && e.response?.statusCode == 401;
    }
    changed();
  }

  bool get limited => user?['limited'] == true;

  Future<void> signIn(Map<String, dynamic> fields) async {
    busy = true;
    error = null;
    changed();
    try {
      await _serial.catchError((Object _) {});
      final next = await api.imsLogin(fields);
      if (user?['id'] != next['id']) {
        idCard = null;
        data = const AppData();
        scope = '';
        pending = [];
        serverRecords = {};
        conflicts = [];
      }
      user = next;
      await db.write('current-user', next);
      await _restore();
      needsLogin = false;
      online = true;
      await synchronize();
    } catch (e) {
      error = Api.message(e);
      rethrow;
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> signOut() async {
    await _serial.catchError((Object _) {});
    if (pending.isNotEmpty) {
      throw StateError('Sync your pending changes before signing out.');
    }
    await api.logout();
    await db.clear();
    user = null;
    idCard = null;
    data = const AppData();
    scope = '';
    serverRecords = {};
    conflicts = [];
    pending = [];
    changed();
  }

  Future<void> loadIdCard({bool refresh = false}) async {
    final owner = _owner;
    if (owner.isEmpty) {
      throw StateError('Sign in with IMS to load your ID card.');
    }
    if (refresh && limited) {
      throw StateError('Verify your IMS login to refresh your ID card.');
    }
    var result = refresh
        ? await api.post('/id-card/refresh')
        : await api.get('/id-card');
    if (!refresh && (result['card'] as Map).isEmpty && !limited) {
      result = await api.post('/id-card/refresh');
    }
    if (_owner != owner) return;
    final payload = Map<String, dynamic>.from(result['card'] as Map);
    if (payload.isEmpty) return;
    final card = StudentIdData.fromJson(payload);
    final student = user?['studentId'] ?? data.account;
    if (card.rollNumber.toUpperCase() != student.toString().toUpperCase()) {
      throw StateError('The ID card belongs to another account.');
    }
    idCard = card;
    await db.write('id-card:$owner', card.toJson());
    user!['name'] = card.name;
    await db.write('current-user', user);
    changed();
  }

  Future<void> setAppearance({String? mode, int? seed, String? clock}) async {
    if (mode != null) {
      theme = mode;
      await db.setPreference('theme', theme);
    }
    if (seed != null) {
      accent = seed;
      await db.setPreference('accent', '$accent');
    }
    if (clock != null) {
      timeFormat = clock;
      await db.setPreference('timeFormat', timeFormat);
    }
    changed();
  }

  Future<void> synchronize() {
    final task = _serial.catchError((Object _) {}).then((_) => _synchronize());
    _serial = task;
    return task;
  }

  Future<void> _synchronize() async {
    if (user == null) return;
    try {
      // Upload the oldest operations first. UUIDs make retries safe after a lost response.
      while (pending.isNotEmpty && !limited) {
        final mutation = pending.first;
        try {
          final saved = await api.post('/records', mutation);
          serverRecords[key(saved['kind'] as String, saved['id'] as String)] =
              saved;
          pending.removeAt(0);
          // Later offline edits of this same record build on the acknowledged revision.
          for (final next in pending) {
            if (next['scope'] == mutation['scope'] &&
                next['kind'] == mutation['kind'] &&
                next['id'] == mutation['id']) {
              next['baseVersion'] = saved['version'];
              break;
            }
          }
          await _persist();
        } on DioException catch (e) {
          if (e.response?.statusCode == 409) {
            conflicts = [mutation];
            break;
          }
          rethrow;
        }
      }
      final state = await api.get('/state');
      imsSessionReady = state['imsSessionReady'] == true;
      final official = Map<String, dynamic>.from(state['official'] as Map);
      if (official.isNotEmpty) {
        final nextScope = state['scope'] as String;
        if (scope.isNotEmpty && scope != nextScope && pending.isNotEmpty) {
          throw StateError(
            'Sync changes in the earlier semester before switching.',
          );
        }
        scope = nextScope;
        serverRecords = {
          for (final r in (state['records'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ))
            key(r['kind'] as String, r['id'] as String): r,
        };
        data = AppData.fromJson(
          official,
        ).copyWith(showPersonal: data.showPersonal);
        _applyRecords();
      }
      online = true;
      needsLogin = false;
      await _persist();
    } catch (e) {
      online = false;
      if (e is DioException && e.response?.statusCode == 401) needsLogin = true;
      error = Api.message(e);
    }
    changed();
  }

  void _applyRecords() {
    final merged = {...serverRecords};
    for (final change in pending.where((m) => m['scope'] == scope)) {
      merged[key(change['kind'] as String, change['id'] as String)] = change;
    }
    List<Map<String, dynamic>> records(String kind) => merged.values
        .where((r) => r['kind'] == kind && r['deleted'] != true)
        .map((r) => Map<String, dynamic>.from(r['payload'] as Map))
        .toList();
    data = data.copyWith(
      sessions: records('personal').map(Session.fromJson).toList(),
      timetable: records('timetable').map(TimetableRule.fromJson).toList(),
      scenarios: records('plan').map(Scenario.fromJson).toList(),
    );
  }

  Future<void> resolveConflict(bool keepLocal) async {
    if (conflicts.isEmpty) return;
    final conflict = conflicts.first;
    if (conflict['scope'] != scope) {
      throw StateError(
        'Return to the original semester before resolving this change.',
      );
    }
    final latest =
        serverRecords[key(
          conflict['kind'] as String,
          conflict['id'] as String,
        )];
    if (keepLocal) {
      conflict['baseVersion'] = latest?['version'] ?? 0;
      conflict['mutationId'] = const Uuid().v4();
    } else {
      pending.removeWhere(
        (m) =>
            m['scope'] == scope &&
            m['kind'] == conflict['kind'] &&
            m['id'] == conflict['id'],
      );
    }
    conflicts = [];
    _applyRecords();
    await _persist();
    changed();
    await synchronize();
  }

  Future<void> mutate(AppData Function(AppData) change) {
    final task = _serial.catchError((Object _) {}).then((_) async {
      if (_owner.isEmpty || scope.isEmpty) {
        throw StateError('Connect IMS and fetch attendance first.');
      }
      final old = data;
      final next = change(data);
      Map<String, Map<String, dynamic>> items(AppData d) => {
        for (final s in d.sessions)
          key('personal', s.id): {
            'kind': 'personal',
            'id': s.id,
            'payload': s.toJson(),
          },
        for (final s in d.timetable)
          key('timetable', s.id): {
            'kind': 'timetable',
            'id': s.id,
            'payload': s.toJson(),
          },
        for (final s in d.scenarios)
          key('plan', s.id): {
            'kind': 'plan',
            'id': s.id,
            'payload': s.toJson(),
          },
      };
      final before = items(old), after = items(next);
      if (limited && jsonEncode(before) != jsonEncode(after)) {
        throw StateError('Sign in with IMS again to change saved records.');
      }
      for (final k in {...before.keys, ...after.keys}) {
        if (jsonEncode(before[k]) == jsonEncode(after[k])) continue;
        final item = after[k] ?? before[k]!;
        pending.add({
          'scope': scope,
          'kind': item['kind'],
          'id': item['id'],
          'payload': item['payload'],
          'deleted': !after.containsKey(k),
          'baseVersion': serverRecords[k]?['version'] ?? 0,
          'mutationId': const Uuid().v4(),
        });
      }
      data = next;
      await _persist();
      changed();
    });
    _serial = task;
    return task.then((_) {
      unawaited(synchronize());
    });
  }

  Future<void> sync() async {
    if (refreshing) return;
    refreshing = true;
    error = null;
    changed();
    try {
      await api.post('/ims/refresh');
      await synchronize();
    } catch (e) {
      error = Api.message(e);
    } finally {
      refreshing = false;
      changed();
    }
  }

  Future<void> saveTimetableDraft(String value) =>
      db.setPreference('timetableDraft:$scope', value);
  Future<void> showPersonal(bool v) =>
      mutate((d) => d.copyWith(showPersonal: v));
  Future<void> mark(Session s, AttendanceStatus status, String note) => mutate(
    (d) => d.copyWith(
      sessions: [
        ...d.sessions.where((e) => e.id != s.id),
        s.mark(status, note),
      ],
    ),
  );
  Future<void> deletePersonalRecord(String id) => mutate(
    (d) => d.copyWith(sessions: d.sessions.where((e) => e.id != id).toList()),
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
        dayOnly(day).isAfter(dayOnly(DateTime.now())) ||
        !data.subjects.any((s) => s.code == subject)) {
      throw ArgumentError(
        'Choose a subject, current or past date and at least one class.',
      );
    }
    final id = const Uuid().v4();
    await mutate(
      (d) => d.copyWith(
        sessions: [
          ...d.sessions,
          if (present > 0)
            Session(
              id: '$id-p',
              subject: subject,
              starts: dayOnly(day),
              weight: present,
              status: AttendanceStatus.present,
            ),
          if (absent > 0)
            Session(
              id: '$id-a',
              subject: subject,
              starts: dayOnly(day),
              weight: absent,
              status: AttendanceStatus.absent,
            ),
        ],
      ),
    );
  }

  Future<void> saveScenario(Scenario s) => mutate(
    (d) =>
        d.copyWith(scenarios: [...d.scenarios.where((e) => e.id != s.id), s]),
  );
  Future<void> deleteScenario(String id) => mutate(
    (d) => d.copyWith(scenarios: d.scenarios.where((e) => e.id != id).toList()),
  );
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
