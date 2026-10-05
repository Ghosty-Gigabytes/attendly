import 'dart:io';
import 'support/fake_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/main.dart';
import 'package:attendly/ui/app.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/data/portal_parser.dart';
import 'package:attendly/domain/models.dart';

class LoginPortal extends PortalService {
  bool reject = false;
  int challenges = 0;
  @override
  Future<LoginChallenge> challenge() async {
    challenges++;
    return LoginChallenge(
      PortalForm(
        Uri.parse('https://www.imsnsit.org/imsnsit/student_login.php'),
        {'HRAND_NUM': 'test'},
        null,
      ),
      File('test/fixtures/captcha.jpg').readAsBytesSync(),
    );
  }

  @override
  Future<void> login(
    LoginChallenge challenge,
    String username,
    String password,
    String captcha,
  ) async {
    if (reject) throw const PortalLoginRejected('The CAPTCHA was rejected.');
  }

  @override
  Future<AppData> fetchAttendance() async =>
      const AppData(account: '12345', semester: 'Test semester');
}

void main() {
  testWidgets(
    'fresh and legacy-demo installs require IMS login; logout returns to login',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AttendanceDatabase.memory(), portal = LoginPortal();
      await tester.runAsync(() async {
        await db.save(
          'demo',
          const AppData(
            subjects: [
              Subject('FAKE', 'Illustrative subject', Counts(18, 24), 0),
            ],
          ),
        );
        await db.setPreference('active', 'demo');
      });
      final controller = AppController(
        db,
        portal,
        credentials: MemoryCredentials(),
        captchaService: FixedCaptcha(),
      );
      addTearDown(controller.dispose);
      await tester.runAsync(controller.initialize);
      expect(controller.authenticated, false);
      expect(controller.data.subjects, isEmpty);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [controllerProvider.overrideWithValue(controller)],
          child: const AttendlyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in to IMS'), findsOneWidget);
      expect(find.text('Illustrative subject'), findsNothing);
      expect(find.text('Track without login'), findsNothing);
      expect(find.text('Overview'), findsNothing);
      expect(find.byKey(const Key('ims-captcha-image')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ims-username')), '12345');
      await tester.enterText(find.byKey(const Key('ims-password')), 'password');
      await tester.enterText(find.byKey(const Key('ims-captcha')), '1234');
      await tester.ensureVisible(find.byKey(const Key('ims-submit')));
      await tester.pumpAndSettle();
      portal.reject = true;
      await tester.tap(find.byKey(const Key('ims-submit')));
      await tester.pumpAndSettle();
      expect(controller.authenticated, false);
      expect(portal.challenges, 2);
      expect(find.text('12345'), findsOneWidget);
      expect(find.text('The CAPTCHA was rejected.'), findsOneWidget);
      portal.reject = false;
      await tester.enterText(find.byKey(const Key('ims-captcha')), '4321');
      await tester.ensureVisible(find.byKey(const Key('ims-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ims-submit')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(controller.authenticated, true);
      expect(find.text('Overview'), findsOneWidget);
      await tester.runAsync(controller.logout);
      await tester.pumpAndSettle();
      expect(find.text('Sign in to IMS'), findsOneWidget);
      expect(find.text('Overview'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
