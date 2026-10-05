import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/ui/calendar.dart';
import 'package:attendly/ui/shared.dart';

void main() {
  test('all supplied codes mean no class and never become absent marks', () {
    for (final code in ['CR', 'CS', 'GH', 'MB', 'MS', 'NA', 'NT', 'OD', 'TL']) {
      final record = OfficialDay('A', '2026-10-06', '$code+$code');
      expect(record.noClass, true, reason: code);
      expect(record.present, 0);
      expect(record.absent, 0);
      expect(record.hasOffMarks, true);
    }
    expect(const OfficialDay('A', '2026-10-06', ' gh + nt ').noClass, true);
    expect(const OfficialDay('A', '2026-10-06', 'UNKNOWN').noClass, false);
    final mixed = const OfficialDay('A', '2026-10-06', '1+NT+0');
    expect(mixed.noClass, false);
    expect(mixed.present, 1);
    expect(mixed.absent, 1);
    expect(mixed.offMarks, ['NT']);
  });
  testWidgets('off day has a blue indicator and only actual codes are shown', (
    tester,
  ) async {
    final c = AppController(AttendanceDatabase.memory(), PortalService());
    addTearDown(c.dispose);
    final date = dateKey(DateTime.now());
    c.data = AppData(
      subjects: const [Subject('A', 'Algebra', Counts(3, 4), 0xff237962)],
      officialDays: [OfficialDay('A', date, 'GH')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CalendarScreen(c, initialSubject: 'A')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('CR'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('GH'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No class'), findsOneWidget);
    expect(
      tester
          .widget<Tag>(
            find.ancestor(of: find.text('GH'), matching: find.byType(Tag)),
          )
          .color,
      offDay,
    );
    expect(c.data.subjects.single.official.held, 4);
    expect(tester.takeException(), isNull);
  });
}
