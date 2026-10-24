import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/ui/timetable_screen.dart';
import 'package:attendly/ui/timetable_editor.dart';

void main() {
  testWidgets(
    'saved timetable is read only, weekday only and honors display clock',
    (tester) async {
      final app = AppController(AttendanceDatabase.memory(), PortalService());
      addTearDown(app.dispose);
      app.data = AppData(
        subjects: const [Subject('CS101', 'Computer Science', Counts(0, 0), 0)],
        timetable: [
          TimetableRule(
            id: 'a',
            subject: 'CS101',
            weekday: 1,
            hour: 14,
            endMinuteOfDay: 960,
            from: DateTime(2020),
            until: DateTime(2100),
            kind: 'lab',
            group: 'G2',
          ),
          TimetableRule(
            id: 'weekend',
            subject: 'CS101',
            weekday: 6,
            hour: 14,
            from: DateTime(2020),
            until: DateTime(2100),
          ),
        ],
      );
      for (final use24 in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: use24),
              child: child!,
            ),
            home: Scaffold(body: TimetableScreen(app)),
          ),
        );
        await tester.pumpAndSettle();
        final grid = tester.widget<WeeklyTimetableGrid>(
          find.byType(WeeklyTimetableGrid),
        );
        expect(grid.editable, false);
        expect(grid.entries.length, 1);
        expect(find.text('Saturday'), findsNothing);
        expect(find.text('Sunday'), findsNothing);
        expect(find.textContaining(use24 ? '14:00' : '2:00 PM'), findsWidgets);
        await tester.ensureVisible(find.text('Computer Science'));
        await tester.tap(find.text('Computer Science'));
        await tester.pumpAndSettle();
        expect(find.textContaining('lab · G2'), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.textContaining('lab · G2'))).pop();
        await tester.pumpAndSettle();
      }
    },
  );
}
