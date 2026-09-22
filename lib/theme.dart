import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle sailuneSystemBars(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}

ThemeData sailuneTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = Color(dark ? 0xffededed : 0xff202020);
  final surface = Color(dark ? 0xff232323 : 0xffffffff);
  final canvas = Color(dark ? 0xff181818 : 0xfff5f5f5);
  final line = Color(dark ? 0xff3b3b3b : 0xffdedede);
  final scheme = ColorScheme.fromSeed(seedColor: ink, brightness: brightness)
      .copyWith(
        primary: ink,
        onPrimary: surface,
        secondary: ink,
        onSecondary: surface,
        surface: surface,
        onSurface: ink,
        surfaceContainerHighest: Color(dark ? 0xff303030 : 0xfff0f0f0),
        outline: Color(dark ? 0xff777777 : 0xffaaaaaa),
        outlineVariant: line,
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: "Sailune",
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      systemOverlayStyle: sailuneSystemBars(brightness),
    ),
    textTheme: ThemeData(brightness: brightness, fontFamily: "Sailune")
        .textTheme
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
            color: ink,
          ),
          titleLarge: TextStyle(
            fontSize: 21,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -.4,
            color: ink,
          ),
        ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: canvas,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: line, space: 32),
  );
}
