import 'package:flutter/material.dart';

class CapyColors {
  static const bg = Color(0xFFFFFFFF);
  static const sidebar = Color(0xFFF7F7F5);
  static const text = Color(0xFF37352F);
  static const textSecondary = Color(0x9E37352F);
  static const divider = Color(0x1737352F);
  static const hover = Color(0x0D37352F);
  static const codeBg = Color(0xFFF7F6F3);
  static const quoteBar = Color(0xFFE3E2E0);
  static const accent = Color(0xFF2383E2);
  static const danger = Color(0xFFEB5757);
}

ThemeData buildCapyTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: CapyColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: CapyColors.text,
      secondary: CapyColors.accent,
      surface: CapyColors.bg,
    ),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: CapyColors.bg,
      foregroundColor: CapyColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: CapyColors.text,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: CapyColors.divider,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: CapyColors.textSecondary),
    textTheme: base.textTheme.apply(
      bodyColor: CapyColors.text,
      displayColor: CapyColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: CapyColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: CapyColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: CapyColors.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CapyColors.text,
        foregroundColor: CapyColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CapyColors.text,
        side: const BorderSide(color: CapyColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
  );
}
