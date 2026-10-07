import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/controller.dart';
import 'data/database.dart';
import 'data/portal_service.dart';
import 'ui/app.dart';
import 'background.dart';

final controllerProvider = Provider<AppController>(
  (ref) => throw UnimplementedError('Override at startup'),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final controller = AppController(
      await AttendanceDatabase.open(),
      PortalService(),
    );
    await controller.initialize();
    runApp(
      ProviderScope(
        overrides: [controllerProvider.overrideWithValue(controller)],
        child: const AttendlyApp(),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Attendly could not open local storage. Restart the app to try again. Existing records have not been reset.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void attendanceBackground() {
  runBackgroundRefresh();
}
