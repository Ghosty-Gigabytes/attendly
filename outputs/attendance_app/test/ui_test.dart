import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/main.dart';
import 'package:attendly/ui/app.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'support/sample_data.dart';

void main() {
  testWidgets('dark appearance persists and all main screens render', (
    tester,
  ) async {
    await (FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController(
      AttendanceDatabase.memory(),
      PortalService(),
    );
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.setTheme('dark');
    });
    expect(
      await tester.runAsync(() => controller.db.preference('theme')),
      'dark',
    );
    controller.scope = 'test-student:semester';
    controller.data = sampleData(DateTime.now());
    controller.authenticated = true;
    addTearDown(controller.dispose);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWithValue(controller)],
        child: RepaintBoundary(key: boundary, child: const AttendlyApp()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    for (final screen in ['Overview', 'Calendar', 'What if?', 'Settings']) {
      await tester.tap(find.text(screen).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (screen == 'Settings') {
        await tester.scrollUntilVisible(find.byType(SegmentedButton<String>), 250, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      if (screen == 'Overview' || screen == 'Settings') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../work/ui-checks')
            ..createSync(recursive: true);
          File(
            '${dir.path}/dark-${screen.toLowerCase()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.runAsync(() => controller.setTheme('light'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile navigation, personal toggle and planner render without overflow',
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
      final controller = AppController(
        AttendanceDatabase.memory(),
        PortalService(),
      );
      await tester.runAsync(controller.initialize);
      controller.scope = 'test-student:semester';
      controller.data = sampleData(DateTime.now());
      controller.authenticated = true;
      addTearDown(controller.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [controllerProvider.overrideWithValue(controller)],
          child: RepaintBoundary(key: boundary, child: const AttendlyApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A little clarity. More freedom.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../work/ui-checks')
            ..createSync(recursive: true);
          File(
            '${dir.path}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('overview');
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('calendar');
      await tester.tap(find.text('What if?').last);
      await tester.pumpAndSettle();
      expect(find.text('What if you took a break?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('planner');
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Display & targets'), findsNothing);
      expect(find.text('Show personal records'), findsNothing);
      await tester.tap(find.text('Overview').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Switch).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(controller.data.showPersonal, true);
      await tester.tap(find.text('Overview').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Engineering Mathematics').first,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await capture('subjects');
      final officialBefore = controller.data.subjects.first.official.toJson();
      final personalBefore = controller.data.sessions.length;
      await tester.tap(find.text('What if?').last);
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 20 && find.text('Take day off').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Take day off').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take day off').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.data.subjects.first.official.toJson(), officialBefore);
      expect(controller.data.sessions.length, personalBefore);
      await capture('planner-sessions');
    },
  );
  testWidgets('tablet layout has no overflow', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController(
      AttendanceDatabase.memory(),
      PortalService(),
    );
    await tester.runAsync(controller.initialize);
    controller.scope = 'test-student:semester';
    controller.data = sampleData(DateTime.now());
    controller.authenticated = true;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWithValue(controller)],
        child: const AttendlyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('What if?').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
