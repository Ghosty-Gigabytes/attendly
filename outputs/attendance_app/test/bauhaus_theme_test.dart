import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/ui/bauhaus_theme.dart';
import 'package:attendly/ui/dashboard.dart';

void main() {
  test('palette persists independently of brightness', () async {
    final app = AppController(AttendanceDatabase.memory(), PortalService());
    addTearDown(app.dispose);
    await app.initialize();
    expect(app.palettePreference, 'material');
    await app.db.setPreference('palette', 'pastel');
    await app.initialize();
    expect(app.palettePreference, 'material');
    await app.setTheme('dark');
    await app.setPalette('bauhaus');
    await app.initialize();
    expect(app.palettePreference, 'bauhaus');
    expect(app.themePreference, 'dark');
    await app.setPalette('classic');
    expect(app.themePreference, 'dark');
  });
  for (final brightness in Brightness.values) {
    testWidgets('bauhaus $brightness renders Overview', (tester) async {
      final app = AppController(AttendanceDatabase.memory(), PortalService());
      addTearDown(app.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: bauhausTheme(brightness),
          home: Scaffold(body: Dashboard(app, onPlan: () {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stay on track. Plan ahead.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final colors = bauhausTheme(brightness).colorScheme;
      final a = colors.onSurface.computeLuminance(),
          b = colors.surface.computeLuminance();
      expect(
        ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
        greaterThan(4.5),
      );
    });
  }
}
