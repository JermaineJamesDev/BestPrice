import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,

  // ── PRIMARY COLORS ──────────────────────────────────────────────────────
  primarySwatch: Colors.blue,
  primaryColor: const Color(0xFF1E3A8A), // “Jamaica blue” here

  // ── BACKGROUND / SCAFFOLD ───────────────────────────────────────────────
  scaffoldBackgroundColor: Colors.white,      // The default background for Scaffold
  // If you ever want to color other surfaces, you can use:
  // cardColor: Colors.white,
  // canvasColor: Colors.grey.shade50,

  // ── APP BAR ─────────────────────────────────────────────────────────────
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A), // correct field name is `backgroundColor`
    foregroundColor: Colors.white,      // text/icon color in AppBar
    elevation: 0,
  ),

  // ── ELEVATED BUTTONS ───────────────────────────────────────────────────
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),

  // ── INPUT FIELDS ────────────────────────────────────────────────────────
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    // In light mode, the default hint/label/text colors will be dark on light
  ),

  // ── TEXT SELECTION (cursor + highlight) ─────────────────────────────────
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Color(0xFF1E3A8A),
    selectionColor: Color(0xFF90CAF9),
    selectionHandleColor: Color(0xFF1E3A8A),
  ),

  // ── OPTIONAL: You could also define a ColorScheme if you want more control:
  // colorScheme: ColorScheme.fromSeed(
  //   seedColor: const Color(0xFF1E3A8A),
  //   brightness: Brightness.light,
  // ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,

  // ── PRIMARY COLORS ──────────────────────────────────────────────────────
  primarySwatch: Colors.blue,
  primaryColor: const Color(0xFF1E3A8A), // keep Jamaica blue as your “primary”

  // ── BACKGROUND / SCAFFOLD ───────────────────────────────────────────────
  scaffoldBackgroundColor: const Color(0xFF121212), // typical dark background
  // Optionally override other dark surfaces:
  // cardColor: const Color(0xFF1E1E1E),
  // canvasColor: const Color(0xFF121212),

  // ── APP BAR ─────────────────────────────────────────────────────────────
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A), // same “Jamaica blue” bar on dark
    foregroundColor: Colors.white,
    elevation: 0,
  ),

  // ── ELEVATED BUTTONS ───────────────────────────────────────────────────
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),

  // ── INPUT FIELDS ────────────────────────────────────────────────────────
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: TextStyle(color: Colors.grey.shade400),
    labelStyle: TextStyle(color: Colors.grey.shade200),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade700),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF1E3A8A)),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),

  // ── TEXT SELECTION (cursor + highlight) ─────────────────────────────────
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Color(0xFF1E3A8A),
    selectionColor: Color(0xFF90CAF9), 
    selectionHandleColor: Color(0xFF1E3A8A),
  ),

  // ── OPTIONAL COLOR SCHEME OVERRIDE ──────────────────────────────────────
  // colorScheme: ColorScheme.dark(
  //   primary: const Color(0xFF1E3A8A),
  //   onPrimary: Colors.white,
  //   background: const Color(0xFF121212),
  //   onBackground: Colors.white70,
  //   surface: const Color(0xFF1E1E1E),
  //   onSurface: Colors.white60,
  // ),
);
