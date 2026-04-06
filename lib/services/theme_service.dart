import 'package:flutter/material.dart';
import 'storage_service.dart';

/// Servicio para persistir y notificar cambios de tema
class ThemeService {
  static const String _themeKey = 'app_theme_mode';
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.system);

  /// Inicializa leyendo la preferencia guardada
  static Future<void> init() async {
    final saved = await StorageService.read(_themeKey);
    switch (saved) {
      case 'dark':
        themeNotifier.value = ThemeMode.dark;
      case 'light':
        themeNotifier.value = ThemeMode.light;
      default:
        themeNotifier.value = ThemeMode.system;
    }
  }

  /// Cambia y persiste el tema
  static Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    await StorageService.write(_themeKey, value);
  }

  static bool get isDark => themeNotifier.value == ThemeMode.dark;
}
