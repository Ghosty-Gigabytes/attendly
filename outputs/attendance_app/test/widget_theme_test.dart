import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/platform_service.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/domain/models.dart';

class WidgetRecorder extends PlatformService {
  int refreshes = 0;
  @override
  Future<void> refreshWidget(AppData data) async {
    refreshes++;
  }
}

void main() {
  test(
    'widget palettes preserve readable text and semantic status in both modes',
    () {
      for (final seed in [0xFF2463BC, 0xFF009688, 0xFF9C27B0, 0xFFFF9800]) {
        for (final brightness in Brightness.values) {
          final colors = widgetColors(seed, brightness);
          double contrast(int a, int b) {
            final x = Color(a).computeLuminance(),
                y = Color(b).computeLuminance();
            return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
          }

          for (final text in [
            'text',
            'muted',
            'accent',
            'error',
            'caution',
            'positive',
          ]) {
            expect(
              contrast(colors[text]!, colors['card']!),
              greaterThanOrEqualTo(4.5),
              reason: '$brightness $text',
            );
          }
          expect(
            contrast(colors['onContainer']!, colors['container']!),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    },
  );
  test(
    'theme and accent changes republish widgets and persist the background seed',
    () async {
      final platform = WidgetRecorder();
      final app = AppController(
        AttendanceDatabase.memory(),
        PortalService(),
        platform: platform,
        systemAccentReader: () async => 0xFF009688,
      );
      addTearDown(app.dispose);
      await app.initialize();
      final initial = platform.refreshes;
      await app.setTheme('dark');
      expect(platform.themeMode, 'dark');
      await app.setMaterialAccent('system');
      expect(platform.accentSeed, 0xFF009688);
      expect(await app.db.preference('widgetAccentSeed'), '${0xFF009688}');
      expect(platform.refreshes, greaterThan(initial));
      await app.setTheme('light');
      expect(platform.themeMode, 'light');
      final snapshot = jsonDecode(
        PlatformService.publication(
              const AppData(),
              themeMode: 'dark',
              accentSeed: 0xFF009688,
            )['widget']
            as String,
      );
      expect(snapshot['themeMode'], 'dark');
      expect(snapshot['lightColors'], isNot(equals(snapshot['darkColors'])));
    },
  );
}
