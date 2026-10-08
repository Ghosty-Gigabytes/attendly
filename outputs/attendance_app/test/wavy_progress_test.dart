import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/ui/wavy_attendance_bar.dart';
import 'package:attendly/ui/material_design.dart';
import 'package:attendly/ui/material_controls.dart';

void main() {
  AttendanceWavePainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<AttendanceWavePainter>()
      .single;
  Widget bar(double value, {bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduced),
      child: Scaffold(
        body: WavyAttendanceBar(
          value: value,
          color: Colors.blue,
          trackColor: Colors.grey,
        ),
      ),
    ),
  );
  testWidgets('wave fills from zero, travels, settles, and updates', (
    tester,
  ) async {
    await tester.pumpWidget(bar(.75));
    expect(painter(tester).value, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter(tester).value, inExclusiveRange(0, .75));
    expect(painter(tester).phase, greaterThan(0));
    await tester.pumpAndSettle();
    expect(painter(tester).value, .75);
    await tester.pumpWidget(bar(.5));
    await tester.pumpAndSettle();
    expect(painter(tester).value, .5);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion goes directly to final percentage', (
    tester,
  ) async {
    await tester.pumpWidget(bar(.8, reduced: true));
    expect(painter(tester).value, .8);
    await tester.pumpWidget(bar(1.5, reduced: true));
    expect(painter(tester).value, 1);
  });
  testWidgets('Material selector opens in a dialog and changes selection', (
    tester,
  ) async {
    String? selected = 'A';
    await tester.pumpWidget(
      MaterialApp(
        theme: materialDesignTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Subject'),
                  content: StatefulBuilder(
                    builder: (context, set) => AppDropdown<String>(
                      value: selected,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'A', child: Text('Algebra')),
                        DropdownMenuItem(value: 'B', child: Text('Biology')),
                      ],
                      onChanged: (v) => set(() => selected = v),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownMenu<String>), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biology').last);
    await tester.pumpAndSettle();
    expect(selected, 'B');
    expect(tester.takeException(), isNull);
  });
}
