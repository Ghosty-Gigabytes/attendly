import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/models.dart';

/// Versioned, transactional snapshots. Official and personal entities have
/// different kinds, and account/semester scopes never share rows.
class AttendanceDatabase extends GeneratedDatabase {
  AttendanceDatabase(super.executor);
  factory AttendanceDatabase.memory() =>
      AttendanceDatabase(NativeDatabase.memory());
  static Future<AttendanceDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    return AttendanceDatabase(
      NativeDatabase.createInBackground(
        File('${dir.path}/attendly.sqlite'),
        setup: (db) {
          db.execute('PRAGMA busy_timeout = 5000');
          db.execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
  }

  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE records (scope TEXT NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(scope,kind,id))',
      );
      await customStatement(
        'CREATE TABLE preferences (id TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    },
  );
  Future<String?> preference(String key) async {
    final rows = await customSelect(
      'SELECT value FROM preferences WHERE id = ?',
      variables: [Variable(key)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('value');
  }

  Future<void> setPreference(String key, String value) => customStatement(
    'INSERT OR REPLACE INTO preferences (id,value) VALUES (?,?)',
    [key, value],
  );
  Future<void> save(String scope, AppData data) => transaction(() async {
    await customStatement('DELETE FROM records WHERE scope = ?', [scope]);
    final json = data.toJson();
    for (final kind in [
      'subjects',
      'officialDays',
      'sessions',
      'timetable',
      'scenarios',
    ]) {
      final values = json.remove(kind) as List;
      for (var i = 0; i < values.length; i++) {
        await customStatement(
          'INSERT INTO records (scope,kind,id,payload) VALUES (?,?,?,?)',
          [scope, kind, '$i', jsonEncode(values[i])],
        );
      }
    }
    await customStatement(
      'INSERT INTO records (scope,kind,id,payload) VALUES (?,?,?,?)',
      [scope, 'meta', 'meta', jsonEncode(json)],
    );
  });
  Future<AppData?> load(String scope) async {
    final rows = await customSelect(
      'SELECT kind,payload FROM records WHERE scope = ? ORDER BY CAST(id AS INTEGER)',
      variables: [Variable(scope)],
    ).get();
    if (rows.isEmpty) return null;
    final json = <String, dynamic>{
      for (final k in [
        'subjects',
        'officialDays',
        'sessions',
        'timetable',
        'scenarios',
      ])
        k: <dynamic>[],
    };
    for (final row in rows) {
      final kind = row.read<String>('kind'),
          value = jsonDecode(row.read<String>('payload'));
      if (kind == 'meta') {
        json.addAll(value as Map<String, dynamic>);
      } else {
        (json[kind] as List).add(value);
      }
    }
    return AppData.fromJson(json);
  }
}
