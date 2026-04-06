import 'package:flutter/material.dart';

/// Colores personalizados de la aplicación — soporta tema claro y oscuro
class AppColors {
  static bool _isDark = false;

  /// Actualiza el modo de color (llamar antes del rebuild)
  static void updateBrightness(bool isDark) => _isDark = isDark;
  static bool get isDark => _isDark;

  // ── Primarios (iguales en ambos temas) ──
  static Color get primary => const Color(0xFF1FBF9F);
  static Color get primaryLight => const Color(0xFF179E85);
  static Color get primarySoft =>
      _isDark
          ? const Color(0xFF1FBF9F).withOpacity(0.22)
          : const Color(0xFF1FBF9F).withOpacity(0.15);
  static Color get secondary => const Color(0xFF1F3A5F);

  // ── Fondos ──
  static Color get background =>
      _isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
  static Color get surface =>
      _isDark ? const Color(0xFF111A2B) : const Color(0xFFFFFFFF);
  static Color get surfaceLight =>
      _isDark ? const Color(0xFF1A263B) : const Color(0xFFF8F9FA);

  // ── Textos ──
  static Color get textPrimary =>
      _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
  static Color get textStrong =>
      _isDark ? const Color(0xFFD7E3F4) : const Color(0xFF1F3A5F);
  static Color get textSecondary =>
      _isDark ? const Color(0xFF9CB0CC) : const Color(0xFF6B6B6B);
  static Color get textSoft =>
      _isDark ? const Color(0xFFB4C2D6) : const Color(0xFF4B5563);
  static Color get placeholder =>
      _isDark ? const Color(0xFF7D8CA4) : const Color(0xFF9CA3AF);

  // ── Bordes ──
  static Color get grey =>
      _isDark ? const Color(0xFF2D3D58) : const Color(0xFFE6E8E7);
  static Color get greyDark =>
      _isDark ? const Color(0xFF2D3D58) : const Color(0xFFE6E8E7);

  // ── Navegación ──
  static Color get navItem =>
      _isDark ? const Color(0xFFC0CEE3) : const Color(0xFF64748B);

  // ── Estados ──
  static Color get success => const Color(0xFF4CAF50);
  static Color get warning => const Color(0xFFFFC107);
  static Color get error => const Color(0xFF991B1B);
  static Color get errorSoft =>
      _isDark
          ? const Color(0xFF991B1B).withOpacity(0.22)
          : const Color(0xFFFEE2E2);
  static Color get pending => const Color(0xFFFF9800);

  // ── Backdrop ──
  static Color get backdrop =>
      _isDark
          ? const Color(0xFF020617).withOpacity(0.65)
          : const Color(0xFF0F172A).withOpacity(0.45);

  // ── Gradientes auth ──
  static Color get authGradientStart =>
      _isDark ? const Color(0xFF104B46) : const Color(0xFF1FBF9F);
  static Color get authGradientEnd =>
      _isDark ? const Color(0xFF0B1220) : const Color(0xFF1F3A5F);
}

/// Tema de la aplicación
class AppTheme {
  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color text,
    required Color textMuted,
    required Color border,
    required Color placeholder,
    required Color danger,
  }) {
    const primary = Color(0xFF1FBF9F);
    const primaryStrong = Color(0xFF179E85);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: primaryStrong,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: text),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger, width: 2),
        ),
        labelStyle: TextStyle(color: textMuted),
        hintStyle: TextStyle(color: placeholder),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: text,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: text,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textMuted,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          color: text,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textMuted,
          fontSize: 14,
        ),
      ),

      dividerTheme: DividerThemeData(color: border),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static final ThemeData lightTheme = _build(
    brightness: Brightness.light,
    background: const Color(0xFFF8FAFC),
    surface: const Color(0xFFFFFFFF),
    text: const Color(0xFF1E293B),
    textMuted: const Color(0xFF6B6B6B),
    border: const Color(0xFFE6E8E7),
    placeholder: const Color(0xFF9CA3AF),
    danger: const Color(0xFF991B1B),
  );

  static final ThemeData darkTheme = _build(
    brightness: Brightness.dark,
    background: const Color(0xFF0B1220),
    surface: const Color(0xFF111A2B),
    text: const Color(0xFFE2E8F0),
    textMuted: const Color(0xFF9CB0CC),
    border: const Color(0xFF2D3D58),
    placeholder: const Color(0xFF7D8CA4),
    danger: const Color(0xFF991B1B),
  );
}
