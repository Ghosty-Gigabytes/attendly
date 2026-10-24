import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import 'shared.dart';
import 'bauhaus_theme.dart';
import 'material_design.dart';
import 'motion.dart';
import 'dashboard.dart';
import 'calendar.dart';
import 'planner_screen.dart';
import 'settings.dart';
import 'login.dart';
import 'timetable_screen.dart';
import 'id_card.dart';

class AttendlyApp extends ConsumerWidget {
  const AttendlyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: ref.watch(controllerProvider),
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendly',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: ref.watch(controllerProvider).use24Hour,
        ),
        child: child!,
      ),
      themeMode: switch (ref.watch(controllerProvider).themePreference) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      darkTheme: ref.watch(controllerProvider).palettePreference == 'material'
          ? materialDesignTheme(
              Brightness.dark,
              seed: Color(ref.watch(controllerProvider).materialSeed),
            )
          : ref.watch(controllerProvider).palettePreference == 'bauhaus'
          ? bauhausTheme(Brightness.dark)
          : ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              fontFamily: 'Roboto',
              scaffoldBackgroundColor: const Color(0xFF0D0E10),
              colorScheme: ColorScheme.fromSeed(
                seedColor: green,
                brightness: Brightness.dark,
                surface: const Color(0xFF181A1D),
                primary: const Color(0xFF83D3B8),
                onSurface: const Color(0xFFE7E8EA),
                onSurfaceVariant: const Color(0xFFADB0B6),
                surfaceContainerLowest: const Color(0xFF090A0C),
                surfaceContainerLow: const Color(0xFF141619),
                surfaceContainer: const Color(0xFF1C1E22),
                surfaceContainerHigh: const Color(0xFF24262B),
                surfaceContainerHighest: const Color(0xFF2D3035),
                outline: const Color(0xFF777B83),
                outlineVariant: const Color(0xFF34373D),
                surfaceTint: Colors.transparent,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0D0E10),
                surfaceTintColor: Colors.transparent,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF222428),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              textTheme: const TextTheme(
                headlineLarge: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
                headlineSmall: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      locale: const Locale('en', 'IN'),
      supportedLocales: const [Locale('en', 'IN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ref.watch(controllerProvider).palettePreference == 'material'
          ? materialDesignTheme(
              Brightness.light,
              seed: Color(ref.watch(controllerProvider).materialSeed),
            )
          : ref.watch(controllerProvider).palettePreference == 'bauhaus'
          ? bauhausTheme(Brightness.light)
          : ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: paper,
              colorScheme: ColorScheme.fromSeed(
                seedColor: green,
                surface: Colors.white,
              ),
              fontFamily: 'Roboto',
              textTheme: const TextTheme(
                headlineLarge: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: ink,
                  letterSpacing: -1,
                ),
                headlineSmall: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
                bodyMedium: TextStyle(color: ink, fontSize: 14),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: paper,
                surfaceTintColor: Colors.transparent,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: paper,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 17,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
      home: const AuthGate(),
    ),
  );
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(controllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => controller.authenticated
          ? AppShell(key: ValueKey(controller.scope))
          : LoginScreen(controller),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(controllerProvider).refreshSystemAccent();
      ref.read(controllerProvider).reloadStored();
      ref.read(controllerProvider).refreshInBackground();
    }
  }

  int index = 0;
  static const labels = [
    'Overview',
    'Calendar',
    'Timetable',
    'ID Card',
    'What if?',
    'Settings',
  ];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.calendar_month_outlined,
    Icons.calendar_view_week_outlined,
    Icons.badge_outlined,
    Icons.auto_awesome_outlined,
    Icons.tune_rounded,
  ];
  void selectDestination(int destination) {
    if (destination == 3) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              IdCardScreen(controller: ref.read(controllerProvider)),
        ),
      );
      return;
    }
    setState(() => index = destination);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(controllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final screens = [
          Dashboard(controller, onPlan: () => selectDestination(4)),
          CalendarScreen(controller),
          TimetableScreen(controller),
          const SizedBox.shrink(),
          PlannerScreen(controller),
          SettingsScreen(controller),
        ];
        return Scaffold(
          appBar: wide
              ? null
              : AppBar(
                  title: Row(
                    children: [
                      Icon(Icons.grain_rounded, color: tone(context, green)),
                      SizedBox(width: 8),
                      Text(
                        isMaterialDesign(context) ? 'Attendly' : 'attendly',
                        style: TextStyle(
                          fontWeight: isMaterialDesign(context)
                              ? FontWeight.w500
                              : FontWeight.w800,
                          letterSpacing: isMaterialDesign(context) ? 0 : -1,
                        ),
                      ),
                    ],
                  ),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (wide && isMaterialDesign(context))
                  NavigationRail(
                    extended: MediaQuery.sizeOf(context).width >= 1200,
                    selectedIndex: index,
                    onDestinationSelected: selectDestination,
                    destinations: [
                      for (var i = 0; i < labels.length; i++)
                        NavigationRailDestination(
                          icon: Icon(icons[i]),
                          label: Text(labels[i]),
                        ),
                    ],
                  ),
                if (wide && !isMaterialDesign(context))
                  Container(
                    width: 230,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        right: BorderSide(color: tone(context, line)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.grain_rounded,
                              color: tone(context, green),
                              size: 32,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'attendly',
                              style: TextStyle(
                                fontSize: 29,
                                fontWeight: FontWeight.w800,
                                color: tone(context, ink),
                                letterSpacing: -1.4,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 9, bottom: 42),
                          child: Text(
                            'MAKE EVERY CLASS COUNT',
                            style: TextStyle(
                              fontSize: 9,
                              color: tone(context, muted),
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        for (var i = 0; i < labels.length; i++)
                          Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                selected: index == i,
                                selectedTileColor: tone(
                                  context,
                                  green,
                                ).withValues(alpha: .09),
                                selectedColor: tone(context, green),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                leading: Icon(icons[i], size: 22),
                                title: Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () => selectDestination(i),
                              ),
                            ),
                          ),
                        Spacer(),
                        Surface(
                          color: tone(context, paper),
                          padding: EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Tag('ON THIS DEVICE'),
                              SizedBox(height: 12),
                              Text(
                                'Your records.\nYour perspective.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Official and personal attendance, always separate.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tone(context, muted),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '75% minimum · per subject',
                          style: TextStyle(
                            fontSize: 11,
                            color: tone(context, muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 1150),
                      child: SmoothTabStack(index: index, children: screens),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  animationDuration: motionDuration(context, 240),
                  selectedIndex: index,
                  onDestinationSelected: selectDestination,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationDestination(
                        icon: Icon(icons[i]),
                        selectedIcon: isMaterialDesign(context)
                            ? Icon(
                                [
                                  Icons.space_dashboard_rounded,
                                  Icons.calendar_month_rounded,
                                  Icons.calendar_view_week_rounded,
                                  Icons.badge_rounded,
                                  Icons.auto_awesome_rounded,
                                  Icons.tune_rounded,
                                ][i],
                              )
                            : null,
                        label: labels[i],
                      ),
                  ],
                ),
        );
      },
    );
  }
}
