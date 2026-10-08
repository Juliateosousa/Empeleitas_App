import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  // core colors
  static const Color ink = Color(0xFF0B0B0B);
  static const Color cream = Color(0xFFF7F1E4);

  // dark green vibe
  static const Color bgDark = Color(0xFF0F2A1D);
  static const Color barDark = Color(0xFF0B1E15);
  static const Color green = Color(0xFF2FE06D);
  static const Color greenDark = Color(0xFF0F5A2E);

  // glow (not const because opacity)
  static Color get greenGlow => green.withValues(alpha: 0.45);

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgDark,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      fontFamily: null,
    );
  }
}

String money(double value) {
  final formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  if (value < 0) {
    return "- ${formatter.format(value.abs())}";
  } else {
    return formatter.format(value);
  }
}
