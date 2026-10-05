import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/ui/calendar.dart';

void main() {
  AppController setup() {
    final c = AppController(AttendanceDatabase.memory(), PortalService());
    c.scope = 'student:semester';
    c.data = const AppData(
      subjects: [Subject('A', 'Algebra', Counts(8, 10), 0xff237962)],
      showPersonal: true,
    );
    return c;
  }

  test(
    'mixed counts persist and deleting one personal entry preserves official totals',
    () async {
      final c = setup();
      addTearDown(c.dispose);
      await c.logClasses('A', DateTime.now(), 1, 1);
      expect(c.data.personalLog('A').attended, 1);
      expect(c.data.personalLog('A').held, 2);
      expect((await c.db.load(c.scope))!.sessions.length, 2);
      await c.deletePersonalRecord(
        c.data.sessions
            .singleWhere((s) => s.status == AttendanceStatus.absent)
            .id,
      );
      expect(c.data.personalLog('A').held, 1);
      expect((await c.db.load(c.scope))!.sessions.length, 1);
      expect(c.data.subjects.single.official.attended, 8);
      expect(c.data.subjects.single.official.held, 10);
      await expectLater(
        c.logClasses('A', DateTime.now(), 0, 0),
        throwsArgumentError,
      );
    },
  );
  testWidgets(
    'log dialog accepts present and absent counts and personal records can be deleted',
    (tester) async {
      final c = setup();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: c,
              builder: (context, _) => CalendarScreen(c, initialSubject: 'A'),
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Log a class'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Log a class'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log a class'));
      await tester.pumpAndSettle();
      expect(find.text('Log an extra class'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('present-1')));
      await tester.ensureVisible(find.byKey(const ValueKey('absent-1')));
      await tester.tap(find.byKey(const ValueKey('absent-1')));
      await tester.pumpAndSettle();
      expect(find.text('Total: 2 classes'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.text('Save'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(c.data.personalLog('A').attended, 1);
      expect(c.data.personalLog('A').held, 2);
      final id = c.data.sessions.first.id;
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('delete-$id')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(ValueKey('delete-$id')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(c.data.sessions.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
