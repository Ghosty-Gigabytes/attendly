import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/main.dart';
import 'package:attendly/ui/app.dart';
import 'package:attendly/ui/material_design.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'support/sample_data.dart';

void main() {
  test('all three designs persist independently of brightness', () async {
    final app = AppController(AttendanceDatabase.memory(), PortalService());
    addTearDown(app.dispose);
    await app.setTheme('dark');
    for (final design in ['material', 'bauhaus', 'classic']) {
      await app.setPalette(design);
      await app.initialize();
      expect(app.palettePreference, design);
      expect(app.themePreference, 'dark');
    }
  });
  for (final mode in ['light', 'dark']) {
    testWidgets('Material $mode renders and navigates all pages', (
      tester,
    ) async {
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
      await tester.runAsync(() async {
        await app.setPalette('material');
        await app.setTheme(mode);
      });
      app.data = sampleData(DateTime(2026, 10, 8));
      app.authenticated = true;
      app.scope = 'test';
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [controllerProvider.overrideWithValue(app)],
          child: RepaintBoundary(key: key, child: const AttendlyApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byType(Scaffold).first),
        ).extension<MaterialDesign>(),
        isNotNull,
      );
      for (final page in ['Overview', 'Calendar', 'What if?', 'Settings']) {
        await tester.tap(find.widgetWithText(NavigationDestination, page));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$mode $page');
        if (const bool.fromEnvironment('RENDER_PREVIEWS')) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final dir = Directory('../material-previews')
              ..createSync(recursive: true);
            File(
              '${dir.path}/$mode-${page.replaceAll('?', '').replaceAll(' ', '-')}.png',
            ).writeAsBytesSync(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.scrollUntilVisible(
        find.text('Material'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(ChoiceChip, 'Classic'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Bauhaus'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Material'), findsOneWidget);
      tester.view.physicalSize = const Size(1100, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
