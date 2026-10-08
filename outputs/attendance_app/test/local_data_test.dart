import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/credential_store.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/platform_service.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/ui/app_information.dart';
import 'support/fake_login.dart';

class DelayedPortal extends PortalService {
  final response = Completer<AppData>();
  @override
  Future<AppData> fetchAttendance() => response.future;
}

class RecordingPlatform extends PlatformService {
  int clears = 0, publishes = 0;
  bool fail = false;
  @override
  Future<void> deleteLocalData() async {
    clears++;
    if (fail) throw PlatformException(code: 'FAILED');
  }

  @override
  Future<void> publish(AppData data, {AppData? previous}) async {
    publishes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final saved = AppData(
    account: 'student',
    semester: 'sem',
    synced: DateTime(2026, 10, 9),
    subjects: const [Subject('A', 'Algebra', Counts(8, 10), 0)],
    sessions: [
      Session(
        id: 'log',
        subject: 'A',
        starts: DateTime(2026, 10, 8),
        status: AttendanceStatus.present,
      ),
    ],
  );
  Future<AppController> setup({
    PortalService? portal,
    RecordingPlatform? platform,
  }) async {
    final db = AttendanceDatabase.memory();
    await db.save('student:sem', saved);
    await db.save('another:old-semester', saved.copyWith(account: 'another'));
    await db.setPreference('active', 'student:sem');
    await db.setPreference('theme', 'dark');
    final controller = AppController(
      db,
      portal ?? PortalService(),
      credentials: MemoryCredentials(const SavedLogin('student', 'secret')),
      platform: platform ?? RecordingPlatform(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    return controller;
  }

  test(
    'delete clears every account, preferences, credentials and platform data',
    () async {
      final platform = RecordingPlatform();
      final app = await setup(platform: platform);
      final before = await app.db.dataEpoch;
      await app.deleteAllLocalData();
      expect(await app.db.load('student:sem'), isNull);
      expect(await app.db.load('another:old-semester'), isNull);
      expect(await app.db.preference('active'), isNull);
      expect(await app.db.preference('theme'), isNull);
      expect(await app.db.dataEpoch, isNot(before));
      expect(await app.credentials.read(), isNull);
      expect(platform.clears, 1);
      expect(app.data.subjects, isEmpty);
      expect(app.authenticated, isFalse);
      expect(app.themePreference, 'system');
      await app.initialize();
      expect(app.authenticated, isFalse);
      expect(app.scope, isEmpty);
    },
  );

  test('a late foreground refresh cannot restore deleted attendance', () async {
    final portal = DelayedPortal();
    final platform = RecordingPlatform();
    final app = await setup(portal: portal, platform: platform);
    // Exercise fetch itself rather than cached-session restoration.
    app.authenticated = false;
    final sync = app.sync();
    await app.deleteAllLocalData();
    portal.response.complete(saved);
    await sync;
    expect(await app.db.load('student:sem'), isNull);
    expect(app.data.subjects, isEmpty);
    expect(platform.publishes, 0);
  });

  test(
    'platform cleanup failure is reported and deletion can be retried',
    () async {
      final platform = RecordingPlatform()..fail = true;
      final app = await setup(platform: platform);
      await expectLater(app.deleteAllLocalData(), throwsStateError);
      expect(app.deletingLocalData, isFalse);
      expect(await app.db.load('student:sem'), isNotNull);
      platform.fail = false;
      await app.deleteAllLocalData();
      expect(await app.db.load('student:sem'), isNull);
    },
  );

  testWidgets('cancel preserves records; confirmation deletes them', (
    tester,
  ) async {
    final app = await setup();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmDeleteLocalData(context, app),
              child: const Text('Manage data'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Manage data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await app.db.load('student:sem'), isNotNull);
    await tester.tap(find.text('Manage data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete local data'));
    await tester.runAsync(() async {
      while (app.deletingLocalData) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(await app.db.load('student:sem'), isNull);
  });

  testWidgets(
    'version comes from installed package and privacy is available offline',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        PlatformService.channel,
        (call) async => {'version': '9.8.7', 'build': '654'},
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(PlatformService.channel, null),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AppInformation())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Version 9.8.7 (build 654)'), findsOneWidget);
      await tester.tap(find.text('Privacy notice'));
      await tester.pumpAndSettle();
      expect(find.text('Your IMS login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
