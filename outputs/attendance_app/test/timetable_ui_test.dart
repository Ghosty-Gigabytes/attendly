import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/domain/timetable.dart';
import 'package:attendly/ui/timetable_editor.dart';

void main() {
  for (final format in ['CSV', 'JSON']) {
    testWidgets(
      'paste $format, review a time grid, and apply without marking attendance',
      (tester) async {
        await (FontLoader('Roboto')
              ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
              ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf')))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = AppController(AttendanceDatabase.memory(), PortalService());
        addTearDown(app.dispose);
        await tester.runAsync(app.initialize);
        app.scope = 'student:semester';
        app.authenticated = true;
        app.data = const AppData(
          account: 'student',
          semester: 'semester',
          subjects: [
            Subject('CS101', 'Computer Science', Counts(18, 24), 0),
            Subject('MA101', 'Mathematics', Counts(20, 24), 1),
          ],
        );
        await tester.runAsync(() => app.db.save(app.scope, app.data));
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              fontFamily: 'Roboto',
              useMaterial3: true,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RepaintBoundary(
                        key: boundary,
                        child: TimetableEditor(app),
                      ),
                    ),
                  ),
                  child: const Text('Open timetable'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open timetable'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Import timetable'));
        await tester.pumpAndSettle();
        expect(find.text('Choose file'), findsNothing);
        await tester.enterText(
          find.byType(TextField),
          format == 'CSV'
              ? '$timetableHeader\nMonday,CS101,09:00,10:00,1\nTuesday,MA101,10:00,12:00,1'
              : jsonEncode({
                  'version': 1,
                  'group': 'G2',
                  'sessions': [
                    {
                      'day': 'Monday',
                      'subject_code': 'CS101',
                      'subject_label': 'CS',
                      'kind': 'lecture',
                      'group': 'all',
                      'start_time': '09:00',
                      'end_time': '10:00',
                      'attendance_count': 1,
                    },
                    {
                      'day': 'Tuesday',
                      'subject_code': 'MA101',
                      'subject_label': 'Math lab G2',
                      'kind': 'lab',
                      'group': 'G2',
                      'start_time': '10:00',
                      'end_time': '12:00',
                      'attendance_count': 1,
                    },
                  ],
                }),
        );
        await tester.ensureVisible(find.text('Review in timetable'));
        await tester.tap(find.text('Review in timetable'));
        await tester.pumpAndSettle();
        expect(find.byType(WeeklyTimetableGrid), findsOneWidget);
        expect(find.text('Computer Science'), findsOneWidget);
        expect(app.data.timetable, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../work/ui-checks')
            ..createSync(recursive: true);
          File(
            '${dir.path}/weekly-timetable.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        // Drafts survive leaving the editor, without changing active rules.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open timetable'));
        await tester.pumpAndSettle();
        expect(find.text('Computer Science'), findsOneWidget);
        expect(app.data.timetable, isEmpty);
        await tester.tap(find.text('Computer Science'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'End time',
          ),
          '10:30',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextField && w.decoration?.labelText == 'Attendance count',
          ),
          '2',
        );
        await tester.ensureVisible(find.text('Done'));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Apply weekly timetable?'), findsOneWidget);
        await tester.tap(find.text('Apply timetable'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(app.data.timetable.length, 2);
        expect(
          app.data.timetable.firstWhere((r) => r.subject == 'MA101').endMinutes,
          720,
        );
        expect(
          app.data.timetable.firstWhere((r) => r.subject == 'CS101').endMinutes,
          630,
        );
        expect(
          app.data.timetable.firstWhere((r) => r.subject == 'CS101').weight,
          2,
        );
        expect(app.data.subjects.first.official.attended, 18);
        expect(app.data.sessions, isEmpty);
        expect(
          await tester.runAsync(
            () => app.db.preference('timetableDraft:${app.scope}'),
          ),
          '',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
