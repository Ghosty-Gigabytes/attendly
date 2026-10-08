import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/ui/material_design.dart';

void main() {
  test('Material defaults, choices persist, and OS changes refresh', () async {
    int? osColor = 0xFF007F86;
    final app = AppController(
      AttendanceDatabase.memory(),
      PortalService(),
      systemAccentReader: () async => osColor,
    );
    addTearDown(app.dispose);
    await app.initialize();
    expect(app.palettePreference, 'material');
    await app.setMaterialAccent('B24C72');
    await app.initialize();
    expect(app.materialSeed, 0xFFB24C72);
    await app.setMaterialAccent('system');
    expect(app.materialSeed, osColor);
    osColor = 0xFF7856A6;
    await app.refreshSystemAccent();
    expect(app.materialSeed, osColor);
    osColor = null;
    await app.refreshSystemAccent();
    expect(app.materialSeed, 0xFF2463BC);
    await app.setPalette('classic');
    await app.initialize();
    expect(app.palettePreference, 'classic');
    expect(app.materialAccent, 'system');
    await app.setMaterialAccent('not-a-color');
    expect(app.materialAccent, 'system');
  });
  test('seed affects Material light and dark while text remains readable', () {
    for (final brightness in Brightness.values) {
      final blue = materialDesignTheme(brightness).colorScheme;
      final rose = materialDesignTheme(
        brightness,
        seed: const Color(0xFFB24C72),
      ).colorScheme;
      expect(rose.primary, isNot(blue.primary));
      final a = rose.primary.computeLuminance(),
          b = rose.onPrimary.computeLuminance();
      expect(
        ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
        greaterThan(4.5),
      );
    }
  });
}
