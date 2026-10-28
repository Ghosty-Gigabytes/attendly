import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly_web/data/api.dart';
import 'package:attendly_web/data/controller.dart';
import 'package:attendly_web/data/store.dart';
import 'package:attendly_web/domain/models.dart';
import 'package:attendly_web/ui/material_design.dart';
import 'package:attendly_web/ui/web_shell.dart';
import 'package:attendly_web/domain/student_id.dart';
import 'package:attendly_web/ui/id_card.dart';
import 'package:attendly_web/ui/id_card_face.dart';

final fixture = AppData(
  account: 'TEST001',
  semester: '2026-27 · Semester 1',
  synced: DateTime(2026, 10, 25),
  subjects: const [Subject('MA101', 'Mathematics', Counts(18, 24), 0xFF2463BC)],
);

final cardFixture = StudentIdData(
  name: 'TEST STUDENT',
  rollNumber: 'TEST001',
  course: 'B.Tech.',
  parentName: 'TEST PARENT',
  branch: 'TEST DEPARTMENT',
  mobile: '1234567890',
  address: 'TEST ADDRESS',
  dob: '01-01-2000',
  issueDate: '01-08-2024',
  bloodGroup: 'O+',
  email: 'student@example.test',
  fetchedAt: DateTime(2026, 10, 28),
);

class FakeApi extends Api {
  FakeApi()
    : super(client: Dio(BaseOptions(baseUrl: "http://localhost:8080/api")));
  bool connected = true, loseReply = false;
  String captchaAnswer = '12345';
  StudentIdData? card;
  final records = <String, Map<String, dynamic>>{},
      seen = <String, Map<String, dynamic>>{};
  void check() {
    if (!connected) {
      throw DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    check();
    if (path == '/id-card') return {'card': card?.toJson() ?? {}};
    if (path == '/auth/me') {
      return {'id': 'owner', 'name': 'Student', 'studentId': 'TEST001'};
    }
    return {
      'scope': 'semester',
      'official': fixture.toJson(),
      'records': records.values.toList(),
      'imsSessionReady': true,
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    check();
    if (path == '/auth/ims/challenge') {
      return {
        'id': 'test-challenge',
        'answer': captchaAnswer,
        'image':
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==',
      };
    }
    if (path == '/id-card/refresh') return {'card': card?.toJson() ?? {}};
    if (path != '/records') return {};
    final m = body!, id = '${m['kind']}|${m['id']}';
    if (seen.containsKey(m['mutationId'])) return seen[m['mutationId']]!;
    final current = records[id]?['version'] ?? 0;
    if (current != m['baseVersion']) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 409,
          data: {'message': 'Conflict'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    final r = <String, dynamic>{
      'kind': m['kind'],
      'id': m['id'],
      'payload': m['payload'],
      'version': current + 1,
      'deleted': m['deleted'],
    };
    records[id] = r;
    seen[m['mutationId'] as String] = r;
    if (loseReply) {
      loseReply = false;
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
      );
    }
    return r;
  }
}

Future<AppController> controller(FakeApi api) async {
  final db = await LocalStore.open();
  await db.clear();
  await db.write('current-user', {
    'id': 'owner',
    'name': 'Student',
    'email': 'student@example.test',
  });
  await db.write('account:owner', {
    'scope': 'semester',
    'data': fixture.toJson(),
    'pending': [],
    'records': {},
  });
  final c = AppController(api, db);
  await c.initialize(connect: false);
  await c.checkSession();
  return c;
}

void main() {
  test('ID card cache is account scoped and clears on logout', () async {
    final api = FakeApi()..card = cardFixture;
    final c = await controller(api);
    await c.loadIdCard();
    expect(c.idCard!.rollNumber, 'TEST001');
    expect((await c.db.read('id-card:owner'))['name'], 'TEST STUDENT');
    api.connected = false;
    final reopened = AppController(api, c.db);
    await reopened.initialize(connect: false);
    expect(reopened.idCard!.rollNumber, 'TEST001');
    reopened.dispose();
    api.connected = true;
    await c.signOut();
    expect(c.idCard, isNull);
    expect(await c.db.read('id-card:owner'), isNull);
    c.dispose();
    await c.db.database.close();
  });
  testWidgets(
    'mobile ID card opens full screen and supports flip rotate and close',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await (FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final boundary = GlobalKey();
      final api = FakeApi()..card = cardFixture;
      final c = (await tester.runAsync(() => controller(api)))!;
      await tester.runAsync(() => c.loadIdCard());
      api.connected = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              RepaintBoundary(key: boundary, child: child!),
          theme: materialDesignTheme(Brightness.light),
          home: WebShell(c),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('mobile-id-card')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(IdCardScreen), findsOneWidget);
      expect(find.byTooltip('Close ID card'), findsOneWidget);
      expect(find.byType(IdCardFace), findsOneWidget);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('../../work/ui-checks/web')
          ..createSync(recursive: true);
        File(
          '${dir.path}/id-card-mobile.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });

      await tester.tap(find.text('Back', skipOffstage: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<IdCardFace>(find.byType(IdCardFace)).back, isTrue);
      await tester.tap(find.text('Landscape card'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Portrait card'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close ID card'));
      await tester.pumpAndSettle();
      expect(find.byType(IdCardScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.runAsync(() => c.db.database.close());
    },
  );

  testWidgets('desktop footer logout clears the session and cached user', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final c = (await tester.runAsync(() => controller(FakeApi())))!;
    c.user!['studentId'] = 'TEST001';
    await tester.pumpWidget(
      MaterialApp(
        theme: materialDesignTheme(Brightness.light),
        home: ListenableBuilder(
          listenable: c,
          builder: (context, _) => WebShell(c),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('sidebar-logout')), findsOneWidget);
    expect(find.text('TEST001'), findsOneWidget);
    expect(find.text('Refresh attendance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Mathematics').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('Close subject attendance'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('desktop-subject-panel'))).width,
      lessThan(1440),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close subject attendance'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('sidebar-logout')));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
    expect(c.user, isNull);
    expect(await tester.runAsync(() => c.db.read('current-user')), isNull);
    expect(find.text('Sign in with IMS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.runAsync(() => c.db.database.close());
  });
  testWidgets(
    'sidebar logout preserves unsynced edits and desktop shortcuts navigate',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = FakeApi();
      final c = (await tester.runAsync(() => controller(api)))!;
      api.connected = false;
      await tester.runAsync(
        () => c.logClasses('MA101', DateTime(2026, 10, 24), 1, 0),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: materialDesignTheme(Brightness.light),
          home: WebShell(c),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('sidebar-logout')));
      await tester.pump();
      expect(find.textContaining('unsynced changes'), findsOneWidget);
      expect(c.user, isNotNull);
      expect(c.pending, hasLength(1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Saved IMS password'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.runAsync(() => c.db.database.close());
    },
  );
  test(
    'limited outage sessions retain pending edits without uploading them',
    () async {
      final api = FakeApi();
      final c = await controller(api);
      api.connected = false;
      await c.logClasses('MA101', DateTime(2026, 10, 24), 1, 0);
      await c.synchronize();
      c.user!['limited'] = true;
      api.connected = true;
      await c.synchronize();
      expect(c.pending, hasLength(1));
      expect(api.records, isEmpty);
      await expectLater(
        c.logClasses('MA101', DateTime(2026, 10, 25), 1, 0),
        throwsStateError,
      );
      expect(c.pending, hasLength(1));
      c.dispose();
      await c.db.database.close();
    },
  );
  test(
    'offline personal edits survive reopening and sync without altering official counts',
    () async {
      final api = FakeApi();
      final actual = await controller(api);
      api.connected = false;
      await actual.logClasses('MA101', DateTime(2026, 10, 24), 1, 1);
      await actual.synchronize();
      expect(actual.pending.length, 2);
      expect(actual.data.personal('MA101').attended, 19);
      expect(actual.data.subjects.single.official.attended, 18);
      final cache = await actual.db.read('account:owner');
      expect((cache as Map)['pending'], hasLength(2));
      final reopened = AppController(api, actual.db);
      await reopened.initialize(connect: false);
      expect(reopened.pending, hasLength(2));
      expect(reopened.data.sessions, hasLength(2));
      reopened.dispose();
      api.connected = true;
      await actual.checkSession();
      expect(actual.pending, isEmpty);
      expect(api.records, hasLength(2));
      expect(actual.data.sessions, hasLength(2));
      actual.dispose();
      await actual.db.database.close();
    },
  );
  test('a lost response is retried once with the same mutation ID', () async {
    final api = FakeApi();
    final actual = await controller(api);
    api.connected = false;
    await actual.logClasses('MA101', DateTime(2026, 10, 24), 1, 0);
    await actual.synchronize();
    api.connected = true;
    api.loseReply = true;
    await actual.synchronize();
    expect(actual.pending, hasLength(1));
    await actual.synchronize();
    expect(actual.pending, isEmpty);
    expect(api.records, hasLength(1));
    expect(api.records.values.single['version'], 1);
    actual.dispose();
    await actual.db.database.close();
  });
  test(
    'conflicting changes stay pending until the user chooses a version',
    () async {
      final api = FakeApi();
      final c = await controller(api);
      api.connected = false;
      await c.logClasses('MA101', DateTime(2026, 10, 24), 1, 0);
      await c.synchronize();
      final m = c.pending.single;
      api.records[c.key(m['kind'] as String, m['id'] as String)] = {
        'kind': m['kind'],
        'id': m['id'],
        'version': 1,
        'deleted': true,
        'payload': m['payload'],
      };
      api.connected = true;
      await c.synchronize();
      expect(c.conflicts, hasLength(1));
      expect(c.data.sessions, hasLength(1));
      await c.resolveConflict(false);
      expect(c.pending, isEmpty);
      expect(c.data.sessions, isEmpty);
      c.dispose();
      await c.db.database.close();
    },
  );
  testWidgets(
    'sign-in works at phone and desktop sizes without fabricated attendance',
    (tester) async {
      await (FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      for (final size in [const Size(390, 844), const Size(1280, 900)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final db = await LocalStore.open();
        final c = AppController(FakeApi(), db);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: materialDesignTheme(Brightness.light),
            home: RepaintBoundary(key: boundary, child: AuthPage(c)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Continue with IMS'), findsOneWidget);
        expect(find.text('IMS student ID'), findsOneWidget);
        expect(find.text('Email'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../work/ui-checks/web')
            ..createSync(recursive: true);
          File(
            '${dir.path}/login-${size.width.toInt()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        c.dispose();
        await db.database.close();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
