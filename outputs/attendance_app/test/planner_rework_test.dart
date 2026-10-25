import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/domain/planner.dart';
import 'package:attendly/ui/planner_screen.dart';
import 'package:attendly/ui/material_design.dart';
import 'package:attendly/ui/bauhaus_theme.dart';

AppData fixture(DateTime date) => AppData(
  account: 'test',
  semester: '1',
  synced: date,
  subjects: const [Subject('MA', 'Mathematics', Counts(18, 24), 0)],
  timetable: [
    for (var day = 1; day <= 7; day++)
      TimetableRule(
        id: 'r$day',
        subject: 'MA',
        weekday: day,
        hour: 9,
        weight: 2,
        from: date,
        until: date.add(const Duration(days: 30)),
      ),
  ],
);

void main() {
  final date = DateTime(2030, 1, 7);
  test(
    'mixed classes count individually, survive saving, and never change actual records',
    () {
      final data = fixture(date);
      final session = data.timetable.first.on(date)!;
      final plan = Scenario(
        id: 'p',
        name: 'One missed',
        from: date,
        until: date,
        actions: {planClassKey(session, 1): PlanAction.miss},
      );
      final saved = Scenario.fromJson(plan.toJson());
      final result = project(data, saved).single;
      expect(result.end.attended, 19);
      expect(result.end.held, 26);
      expect(result.steps.length, 2);
      expect(data.subjects.single.official.attended, 18);
      expect(data.subjects.single.official.held, 24);
      final actions = {...saved.actions};
      setSessionAction(actions, session, PlanAction.cancel);
      final holiday = Scenario(
        id: 'h',
        name: 'Holiday',
        from: date,
        until: date,
        actions: actions,
      );
      expect(project(data, holiday).single.end.held, 24);
      setSessionAction(actions, session, PlanAction.attend);
      expect(actions, isEmpty);
    },
  );
  test(
    'legacy block choices and individual cancelled classes remain compatible',
    () {
      final data = fixture(date),
          session = fixture(date).timetable.first.on(date)!;
      final plan = Scenario(
        id: 'p',
        name: 'old',
        from: date,
        until: date,
        actions: {
          session.id: PlanAction.miss,
          planClassKey(session, 1): PlanAction.cancel,
        },
      );
      final result = project(data, plan).single;
      expect(result.end.attended, 18);
      expect(result.end.held, 25);
    },
  );
  test(
    'changing the window excludes old choices and extra classes outside it',
    () {
      final data = fixture(date);
      final session = data.timetable.first.on(date)!;
      final plan = Scenario(
        id: 'p',
        name: 'later',
        from: date.add(const Duration(days: 1)),
        until: date.add(const Duration(days: 1)),
        actions: {session.id: PlanAction.miss},
        extras: [Session(id: 'extra', subject: 'MA', starts: date)],
      );
      expect(project(data, plan).single.end.attended, 20);
      expect(project(data, plan).single.end.held, 26);
    },
  );
  testWidgets(
    'guided plan edits one of two classes, reverses a day off, and shows per-subject results',
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
      final tomorrow = dayOnly(DateTime.now()).add(const Duration(days: 1));
      final controller = AppController(
        AttendanceDatabase.memory(),
        PortalService(),
      );
      controller.scope = 'test:1';
      controller.data = fixture(tomorrow);
      controller.authenticated = true;
      addTearDown(controller.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: materialDesignTheme(Brightness.light),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(body: PlannerScreen(controller)),
          ),
        ),
      );
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../work/ui-checks/planner')
            ..createSync(recursive: true);
          File(
            '${dir.path}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> tap(String text) async {
        await tester.scrollUntilVisible(
          find.text(text),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }

      expect(find.text('When are you planning?'), findsOneWidget);
      await capture('dates');
      await tap('Choose classes');
      expect(find.text('Mark what you’ll miss'), findsOneWidget);
      await capture('classes');
      final session = controller.data.timetable
          .firstWhere((r) => r.weekday == tomorrow.weekday)
          .on(tomorrow)!;
      final miss = find.byKey(ValueKey('plan-${session.id}-1-miss'));
      await tester.ensureVisible(miss);
      await tester.pumpAndSettle();
      await tester.tap(miss);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(miss).selected, true);
      await tap('Day off');
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Day off'))
            .selected,
        true,
      );
      await tap('Day off');
      await tester.ensureVisible(miss);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(miss).selected, false);
      await tester.tap(miss);
      await tester.pumpAndSettle();
      await tap('See results');
      expect(find.text('Here’s how your plan looks'), findsOneWidget);
      expect(find.text('13 attend'), findsOneWidget);
      expect(find.text('1 miss'), findsOneWidget);
      expect(find.text('MA · Mathematics'), findsOneWidget);
      expect(find.textContaining('Mathematics'), findsWidgets);
      expect(find.text('After plan'), findsOneWidget);
      expect(controller.data.subjects.single.official.attended, 18);
      expect(tester.takeException(), isNull);
      await capture('results');
    },
  );
  testWidgets('no timetable gives a setup action and disables proceeding', (
    tester,
  ) async {
    final controller = AppController(
      AttendanceDatabase.memory(),
      PortalService(),
    );
    controller.scope = 'empty';
    controller.data = fixture(DateTime.now()).copyWith(timetable: []);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PlannerScreen(controller))),
    );
    await tester.scrollUntilVisible(
      find.text('Choose classes'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Choose classes'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Set up your timetable first'), findsOneWidget);
  });
  testWidgets(
    'planner remains usable in light, dark, classic and Bauhaus with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController(
        AttendanceDatabase.memory(),
        PortalService(),
      );
      controller.scope = 'test:1';
      controller.data = fixture(
        dayOnly(DateTime.now()).add(const Duration(days: 1)),
      );
      addTearDown(controller.dispose);
      final themes = [
        materialDesignTheme(Brightness.light),
        materialDesignTheme(Brightness.dark),
        ThemeData(useMaterial3: true),
        bauhausTheme(Brightness.light),
      ];
      for (var i = 0; i < themes.length; i++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: themes[i],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(body: PlannerScreen(controller, key: ValueKey(i))),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('2 · Classes'),
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('2 · Classes'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('3 · Results'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
