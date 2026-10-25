import 'package:flutter/material.dart';

class BauhausPalette extends ThemeExtension<BauhausPalette> {
  final Color muted, positive, caution, negative, offDay;
  const BauhausPalette({
    required this.muted,
    required this.positive,
    required this.caution,
    required this.negative,
    required this.offDay,
  });
  @override
  BauhausPalette copyWith({
    Color? muted,
    Color? positive,
    Color? caution,
    Color? negative,
    Color? offDay,
  }) => BauhausPalette(
    muted: muted ?? this.muted,
    positive: positive ?? this.positive,
    caution: caution ?? this.caution,
    negative: negative ?? this.negative,
    offDay: offDay ?? this.offDay,
  );
  @override
  BauhausPalette lerp(covariant BauhausPalette? other, double t) =>
      other == null
      ? this
      : BauhausPalette(
          muted: Color.lerp(muted, other.muted, t)!,
          positive: Color.lerp(positive, other.positive, t)!,
          caution: Color.lerp(caution, other.caution, t)!,
          negative: Color.lerp(negative, other.negative, t)!,
          offDay: Color.lerp(offDay, other.offDay, t)!,
        );
}

ThemeData bauhausTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = Color(dark ? 0xFF171717 : 0xFFF3EFE5);
  final surface = Color(dark ? 0xFF242424 : 0xFFFCF9F0);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF174CBD),
    brightness: brightness,
    primary: Color(dark ? 0xFFFFD447 : 0xFF174CBD),
    onPrimary: Color(dark ? 0xFF171717 : 0xFFFFFFFF),
    primaryContainer: Color(dark ? 0xFF173D89 : 0xFFFFD447),
    onPrimaryContainer: Color(dark ? 0xFFFFD447 : 0xFF171717),
    secondary: Color(dark ? 0xFF93CDA6 : 0xFF27663D),
    surface: surface,
    onSurface: Color(dark ? 0xFFF5F0E6 : 0xFF181818),
    onSurfaceVariant: Color(dark ? 0xFFC5C0B5 : 0xFF5D5952),
    outlineVariant: Color(dark ? 0xFF77746D : 0xFF242424),
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: background,
    colorScheme: scheme,
    extensions: [
      BauhausPalette(
        muted: scheme.onSurfaceVariant,
        positive: Color(dark ? 0xFF93CDA6 : 0xFF27663D),
        caution: Color(dark ? 0xFFFFD447 : 0xFF875200),
        negative: Color(dark ? 0xFFFF9285 : 0xFFB52E21),
        offDay: Color(dark ? 0xFF93B7FF : 0xFF174CBD),
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -.7,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const RoundedRectangleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(),
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(const RoundedRectangleBorder()),
      ),
    ),
    dialogTheme: const DialogThemeData(shape: RoundedRectangleBorder()),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1.5,
    ),
  );
}
