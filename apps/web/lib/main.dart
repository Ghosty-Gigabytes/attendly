import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/api.dart';
import 'data/controller.dart';
import 'data/store.dart';
import 'ui/material_design.dart';
import 'ui/web_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WebStartup());
}

class WebStartup extends StatefulWidget {
  const WebStartup({super.key});
  @override
  State<WebStartup> createState() => _WebStartupState();
}

class _WebStartupState extends State<WebStartup> {
  AppController? controller;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(start());
  }

  Future<void> start() async {
    try {
      final c = AppController(Api(), await LocalStore.open());
      await c.initialize();
      if (mounted) setState(() => controller = c);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not open browser storage. Allow site storage and reload Attendly.',
        );
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: error == null
                ? Image.asset('assets/logo.png', width: 288, height: 288)
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(error!),
                  ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => MaterialApp(
        title: 'Attendly',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en', 'IN')],
        theme: materialDesignTheme(Brightness.light, seed: Color(c.accent)),
        darkTheme: materialDesignTheme(Brightness.dark, seed: Color(c.accent)),
        themeMode: switch (c.theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: c.use24Hour),
          child: child!,
        ),
        home: WebShell(c),
      ),
    );
  }
}
