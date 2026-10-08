import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/ui/wavy_attendance_bar.dart';

void main() {
  double progress(WidgetTester tester, String id, int generation) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byKey(ValueKey('$id-$generation')),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((w) => w.painter)
      .whereType<AttendanceWavePainter>()
      .single
      .value;
  testWidgets(
    'offscreen waves wait for scrolling and refresh restarts only visible bars',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      int generation = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) {
              update = set;
              Widget wave(String id) => WavyAttendanceBar(
                key: ValueKey('$id-$generation'),
                value: .75,
                color: Colors.blue,
                trackColor: Colors.grey,
              );
              return Scaffold(
                body: SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    controller: scroll,
                    child: Column(
                      children: [
                        wave('top'),
                        const SizedBox(height: 800),
                        wave('bottom'),
                        const SizedBox(height: 300),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(progress(tester, 'top', 0), .75);
      expect(progress(tester, 'bottom', 0), 0);
      scroll.jumpTo(750);
      await tester.pump();
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
      expect(progress(tester, 'bottom', 0), inExclusiveRange(0, .75));
      await tester.pumpAndSettle();
      update(() => generation++);
      await tester.pumpAndSettle();
      expect(progress(tester, 'bottom', 1), .75);
      expect(progress(tester, 'top', 1), 0);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
      expect(progress(tester, 'top', 1), inExclusiveRange(0, .75));
      await tester.pumpAndSettle();
      expect(progress(tester, 'top', 1), .75);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('hidden tabs wait and partially filled waves pause until shown', (
    tester,
  ) async {
    bool enabled = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, set) {
            update = set;
            return Scaffold(
              body: TickerMode(
                enabled: enabled,
                child: const WavyAttendanceBar(
                  key: ValueKey('bar-0'),
                  value: .8,
                  color: Colors.blue,
                  trackColor: Colors.grey,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(progress(tester, 'bar', 0), 0);
    update(() => enabled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    update(() => enabled = false);
    await tester.pump();
    final paused = progress(tester, 'bar', 0);
    await tester.pump(const Duration(seconds: 3));
    expect(progress(tester, 'bar', 0), paused);
    update(() => enabled = true);
    await tester.pumpAndSettle();
    expect(progress(tester, 'bar', 0), .8);
  });
}
