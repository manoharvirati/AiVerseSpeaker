part of '../../app/speak_flow_app.dart';

class AppTheme {
  static const royalBlue = Color(0xFF2563EB);
  static const indigo = Color(0xFF4F46E5);
  static const emerald = Color(0xFF22C55E);
  static const purple = Color(0xFF7C3AED);
  static const violet = Color(0xFFA855F7);
  static const sky = Color(0xFF38BDF8);
  static const orange = Color(0xFFF59E0B);
  static const coral = Color(0xFFFB7185);
  static const offWhite = Color(0xFFF8FAFC);
  static const navy = Color(0xFF09090B);
  static const surface = Color(0xFF18181B);
  static const card = Color(0xFF111327);
  static const ink = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA1A1AA);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: royalBlue,
      brightness: Brightness.light,
      primary: royalBlue,
      secondary: emerald,
      surface: Colors.white,
      error: coral,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: offWhite,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: _textTheme(Brightness.light),
      navigationBarTheme: _navigationBarTheme(scheme),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.dark,
      primary: purple,
      secondary: sky,
      surface: surface,
      error: coral,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: navy,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: _textTheme(Brightness.dark),
      navigationBarTheme: _navigationBarTheme(scheme),
      iconTheme: const IconThemeData(color: Color(0xFFE5E7EB)),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark ? Colors.white : ink;
    return GoogleFonts.poppinsTextTheme(
      TextTheme(
      displaySmall: TextStyle(
        color: color,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
      headlineMedium: TextStyle(
        color: color,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: color,
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: color, fontSize: 16, height: 1.45),
      bodyMedium: const TextStyle(color: muted, fontSize: 14, height: 1.45),
      labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
    );
  }

  static NavigationBarThemeData _navigationBarTheme(ColorScheme scheme) {
    return NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : AppTheme.muted,
        ),
      ),
    );
  }
}


