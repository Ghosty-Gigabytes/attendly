import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/ui/dashboard.dart';
import 'package:attendly/ui/calendar.dart';

void main() {
  test(
    'official cells distinguish no class, present, absent and repeated classes',
    () {
      expect(const OfficialDay('A', '2026-10-01', ' ').description, 'No class');
      expect(const OfficialDay('A', '2026-10-01', '0').description, '1 absent');
      expect(
        const OfficialDay('A', '2026-10-01', '1').description,
        '1 present',
      );
      final mixed = const OfficialDay('A', '2026-10-01', '1+0+1+NT');
      expect(mixed.present, 2);
      expect(mixed.absent, 1);
      expect(mixed.description, '2 present · 1 absent · NT');
    },
  );
  testWidgets(
    'overview subject opens a filtered calendar with separate percentages',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController(AttendanceDatabase.memory(), PortalService());
      addTearDown(c.dispose);
      c.data = AppData(
        subjects: const [Subject('A', 'Algebra', Counts(3, 4), 0xff237962)],
        officialDays: [OfficialDay('A', dateKey(DateTime.now()), '')],
        showPersonal: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showSubject(context, c.data.subjects.single, c),
                child: const Text('Open subject'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open subject'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Official 75.0% · 3/4'), findsOneWidget);
      expect(find.text('With personal 75.0%'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No class'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No class'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
