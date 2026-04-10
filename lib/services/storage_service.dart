import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio para almacenar datos de forma segura
/// 
/// flutter_secure_storage que encripta los datos:
/// - En Android usa EncryptedSharedPreferences
/// - En iOS usa Keychain
class StorageService {
  static const _storage = FlutterSecureStorage();
  
  // Claves para almacenar datos
  static const String _tokenKey = 'access_token';
  static const String _userIdKey = 'user_id';
  static const String _dismissedNotifsKey = 'dismissed_notification_ids';

  /// Guarda el token de acceso de forma segura
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Obtiene el token de acceso
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Guarda el ID del usuario
  static Future<void> saveUserId(int userId) async {
    await _storage.write(key: _userIdKey, value: userId.toString());
  }

  /// Obtiene el ID del usuario
  static Future<int?> getUserId() async {
    final value = await _storage.read(key: _userIdKey);
    return value != null ? int.tryParse(value) : null;
  }

  /// Elimina todos los datos almacenados (para logout)
  /// Preserva la preferencia de tema del usuario
  static Future<void> clearAll() async {
    final theme = await _storage.read(key: 'app_theme_mode');
    await _storage.deleteAll();
    if (theme != null) {
      await _storage.write(key: 'app_theme_mode', value: theme);
    }
  }

  /// Verifica si hay un token guardado
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Lee un valor genérico por clave
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Escribe un valor genérico por clave
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // ── Notificaciones descartadas ──

  /// Obtiene los IDs de notificaciones descartadas por el usuario
  static Future<Set<int>> getDismissedNotificationIds() async {
    final value = await _storage.read(key: _dismissedNotifsKey);
    if (value == null || value.isEmpty) return {};
    return value.split(',').map((s) => int.tryParse(s)).whereType<int>().toSet();
  }

  /// Agrega un ID de notificación a la lista de descartadas
  static Future<void> dismissNotification(int id) async {
    final ids = await getDismissedNotificationIds();
    ids.add(id);
    await _storage.write(key: _dismissedNotifsKey, value: ids.join(','));
  }

  /// Agrega múltiples IDs de notificaciones descartadas
  static Future<void> dismissNotifications(List<int> newIds) async {
    final ids = await getDismissedNotificationIds();
    ids.addAll(newIds);
    await _storage.write(key: _dismissedNotifsKey, value: ids.join(','));
  }
}
