import 'package:flutter/material.dart';

/// Central Mindanao University style: grass green, white and yellow.
const grassGreen = Color(0xFF2B7A2B);
const deepGreen = Color(0xFF1E5A1E);
const sunYellow = Color(0xFFFFC72C);
const paleGreen = Color(0xFFF3F8EE);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: grassGreen,
    brightness: Brightness.light,
  ).copyWith(
    primary: grassGreen,
    onPrimary: Colors.white,
    secondary: sunYellow,
    onSecondary: deepGreen,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paleGreen,
    // Green top bar with a yellow line underneath.
    appBarTheme: const AppBarTheme(
      backgroundColor: grassGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: sunYellow, width: 3)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: grassGreen,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: grassGreen,
        side: const BorderSide(color: grassGreen),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: grassGreen),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: sunYellow,
      foregroundColor: deepGreen,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: grassGreen, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: sunYellow,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFDDE8D5)),
  );
}
