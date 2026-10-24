import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Roboto',
    ], await rootBundle.loadString('assets/fonts/roboto_license.txt'));
  });
  runApp(const StartupApp());
}

class StartupApp extends StatefulWidget {
  const StartupApp({super.key});
  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  AppController? _controller;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      final controller = AppController(
        await AttendanceDatabase.open(),
        PortalService(),
      );
      await controller.initialize(deferPlatformWork: true);
      await controller.prepareStartupTheme();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(controller.finishStartupAppearance());
        unawaited(controller.refreshInBackground());
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return ProviderScope(
        overrides: [controllerProvider.overrideWithValue(controller)],
        child: const AttendlyApp(),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _failed
                ? const Text(
                    'Attendly could not open local storage. Restart the app to try again. Existing records have not been reset.',
                  )
                : Image.asset(
                    'assets/splash_logo.png',
                    width: 288,
                    height: 288,
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

