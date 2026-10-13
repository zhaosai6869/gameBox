import 'package:flutter/material.dart';

const bg = Color(0xFF0E1116);
const cardBg = Color(0xFF171C24);
const fgColor = Color(0xFFE6E9EF);

const gameAccent = <String, Color>{'jcc': Color(0xFFE0A93B), 'bsy': Color(0xFF37D6C0)};

ThemeData buildTheme(String gameId) {
  final accent = gameAccent[gameId] ?? gameAccent['jcc']!;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
    scaffoldBackgroundColor: bg,
  );
  return base.copyWith(
    cardTheme: const CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    appBarTheme: AppBarTheme(backgroundColor: bg, foregroundColor: fgColor, elevation: 0),
    listTileTheme: ListTileThemeData(
      iconColor: accent,
      titleTextStyle: const TextStyle(
        color: fgColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 13),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF232A35), space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: cardBg,
      side: const BorderSide(color: Color(0xFF2A3240)),
      labelStyle: const TextStyle(color: fgColor, fontSize: 13),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Color(0xFF68727F)),
    ),
    textTheme: base.textTheme.apply(bodyColor: fgColor, displayColor: fgColor),
  );
}

Widget placeholderThumb(String seed, double size, Color accent) {
  final code = seed.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xFFFF);
  final hue = (code % 360) / 360.0;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: HSLColor.fromAHSL(1, hue * 360, 0.35, 0.28).toColor(),
      borderRadius: BorderRadius.circular(size * 0.2),
    ),
    child: Center(
      child: Text(
        seed.isEmpty ? '？' : String.fromCharCode(seed.runes.first),
        style: TextStyle(
          color: accent,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
