import 'package:flutter/material.dart';
import 'storage_service.dart';

/// Servicio para persistir y notificar cambios de tema
class ThemeService {
  static const String _themeKey = 'app_theme_mode';
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.light);

  /// Inicializa leyendo la preferencia guardada
  static Future<void> init() async {
    final saved = await StorageService.read(_themeKey);
    if (saved == 'dark') {
      themeNotifier.value = ThemeMode.dark;
    } else {
      themeNotifier.value = ThemeMode.light;
    }
  }

  /// Cambia y persiste el tema
  static Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    await StorageService.write(
        _themeKey, mode == ThemeMode.light ? 'light' : 'dark');
  }

  static bool get isDark => themeNotifier.value == ThemeMode.dark;
}
