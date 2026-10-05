import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/credential_store.dart';
import 'package:attendly/ui/login.dart';
import 'support/fake_login.dart';
import 'login_ui_test.dart' show LoginPortal;

void main() {
  testWidgets(
    'saved login authenticates automatically and sign out forgets it',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.attendly/permission'), (_) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.attendly/permission'), null));
      final store = MemoryCredentials(const SavedLogin('12345', 'secret'));
      final portal = LoginPortal();
      final c = AppController(
        AttendanceDatabase.memory(),
        portal,
        credentials: store,
        captchaService: FixedCaptcha('1234'),
      );
      addTearDown(c.dispose);
      await tester.runAsync(() async { await c.db.customSelect('SELECT 1').get(); });
      await tester.pumpWidget(MaterialApp(home: LoginScreen(c)));
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while ((!c.authenticated || c.busy) && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(c.authenticated, true);
      expect(portal.challenges, 1);
      expect(store.value!.password, 'secret');
      await tester.runAsync(c.logout);
      expect(store.value, isNull);
      expect(c.authenticated, false);
    },
  );
  testWidgets(
    'rejected automatic login stops after one attempt and retains credentials',
    (tester) async {
      final store = MemoryCredentials(const SavedLogin('12345', 'secret'));
      final portal = LoginPortal()..reject = true;
      final c = AppController(
        AttendanceDatabase.memory(),
        portal,
        credentials: store,
        captchaService: FixedCaptcha('1234'),
      );
      addTearDown(c.dispose);
      await tester.runAsync(() async { await c.db.customSelect('SELECT 1').get(); });
      await tester.pumpWidget(MaterialApp(home: LoginScreen(c)));
      await tester.pumpAndSettle();
      expect(c.authenticated, false);
      expect(portal.challenges, 2);
      expect(find.text('The CAPTCHA was rejected.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ims-username')))
            .controller!
            .text,
        '12345',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ims-password')))
            .controller!
            .text,
        'secret',
      );
    },
  );
  testWidgets('unreadable CAPTCHA leaves saved login ready for manual entry', (
    tester,
  ) async {
    final c = AppController(
      AttendanceDatabase.memory(),
      LoginPortal(),
      credentials: MemoryCredentials(const SavedLogin('12345', 'secret')),
      captchaService: FixedCaptcha(),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(c)));
    await tester.pumpAndSettle();
    expect(c.authenticated, false);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ims-password')))
          .controller!
          .text,
      'secret',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('ims-submit')))
          .onPressed,
      isNotNull,
    );
  });
}
