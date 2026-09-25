import 'package:flutter/material.dart';

const String appFontFamily = 'IBMPlexSansArabic';

const Color appSeedColor = Color(0xFF00695C);

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadius {
  static const double large = 16;
}

abstract final class AppMarkerColors {
  static const Color fixed = Color(0xFF00695C);
  static const Color live = Color(0xFFE65100);
}

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: appSeedColor);

  const RoundedRectangleBorder largeShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.large)),
  );
  final ButtonStyle buttonStyle = ButtonStyle(
    shape: WidgetStateProperty.all(largeShape),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    appBarTheme: const AppBarTheme(centerTitle: true),
    cardTheme: const CardThemeData(shape: largeShape),
    dialogTheme: const DialogThemeData(shape: largeShape),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: largeShape,
    ),
  );
}
