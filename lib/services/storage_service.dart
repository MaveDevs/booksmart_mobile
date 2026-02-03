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
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Verifica si hay un token guardado
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
