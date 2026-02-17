import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

/// Resultado de una operacion de API
/// Contiene los datos o un mensaje de error
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool success;

  ApiResult.success(this.data)
      : error = null,
        success = true;

  ApiResult.failure(this.error)
      : data = null,
        success = false;
}

/// Servicio para comunicarse con la API
class ApiService {
  /// Realiza el login del usuario
  /// Retorna el token si es exitoso o un error si falla
  static Future<ApiResult<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(Duration(seconds: ApiConfig.timeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);
        
        // Guardar el token de forma segura
        await StorageService.saveToken(authResponse.accessToken);
        
        return ApiResult.success(authResponse);
      } else if (response.statusCode == 422) {
        // Error de validacion
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = data['detail'];
        if (detail is List && detail.isNotEmpty) {
          return ApiResult.failure(detail[0]['msg'] as String? ?? 'Error de validacion');
        }
        return ApiResult.failure('Datos invalidos');
      } else if (response.statusCode == 401) {
        return ApiResult.failure('Correo o contrasena incorrectos');
      } else {
        return ApiResult.failure('Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet. Verifica tu red.');
    } on http.ClientException {
      return ApiResult.failure('Error de conexion. Verifica que el servidor este activo.');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Registra un nuevo usuario
  static Future<ApiResult<UserModel>> register({
    required String nombre,
    required String apellido,
    required String correo,
    required String contrasena,
    int rolId = 1,  // Rol por defecto (usuario normal)
    bool activo = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'nombre': nombre,
              'apellido': apellido,
              'correo': correo,
              'contrasena': contrasena,
              'rol_id': rolId,
              'activo': activo,
            }),
          )
          .timeout(Duration(seconds: ApiConfig.timeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(data);
        return ApiResult.success(user);
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = data['detail'];
        if (detail is List && detail.isNotEmpty) {
          return ApiResult.failure(detail[0]['msg'] as String? ?? 'Error de validacion');
        }
        return ApiResult.failure('Datos invalidos');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResult.failure(data['detail'] as String? ?? 'El correo ya esta registrado');
      } else {
        return ApiResult.failure('Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } on http.ClientException {
      return ApiResult.failure('Error de conexion');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Obtiene los datos del usuario por ID
  static Future<ApiResult<UserModel>> getUser(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return ApiResult.failure('No hay sesion activa');
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.userEndpoint}/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: ApiConfig.timeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(data);
        return ApiResult.success(user);
      } else if (response.statusCode == 401) {
        return ApiResult.failure('Sesion expirada');
      } else if (response.statusCode == 404) {
        return ApiResult.failure('Usuario no encontrado');
      } else {
        return ApiResult.failure('Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  // obtiene la informacion del usuario actual

  static Future<ApiResult<UserModel>> getCurrentUser() async {
    try {
      final token = await StorageService.getToken();
      if (token == null){
        return ApiResult.failure("No hay sesion activa");
      }
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization' : 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(UserModel.fromJson(data));
      } else if (response.statusCode == 401) {
        return ApiResult.failure('Sesion expirada');
      }else {
        return ApiResult.failure('Error al obtener usuario');
      }
    } on SocketException {
      return ApiResult.failure("Sin Conexion a Internet");
    } 
    catch (e) {
      return ApiResult.failure("Error inseperado: $e");
    }
  }


  // Actualizar la informacion del usuario

  static Future<ApiResult<UserModel>> updateUser({
    required int userId,
    String? nombre,
    String? apellido,
    String? correo,
    String? contrasena,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return ApiResult.failure('No hay sesion activa');
      }

      // Contruye el body solo con campos no nulos
      final Map<String, dynamic> body = {};
      if (nombre != null) body ['nombre'] = nombre;
      if (apellido != null) body ['apellido'] = apellido;
      if (correo != null) body ['correo'] = correo;
      if (contrasena != null) body ['contrasena'] = contrasena;

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(UserModel.fromJson(data));
      } else if (response.statusCode == 401) {
        return ApiResult.failure('Sesion expirada');
      } else if (response.statusCode == 422) {
        return ApiResult.failure('Datos Invalidos');
      } else {
        return ApiResult.failure('Error al actualizar');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  // Desactiva la cuenta del usuario (soft delete)
  static Future<ApiResult<bool>> deactivateAccount(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return ApiResult.failure('No hay sesion activa');
      }

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'activo': false}),
      );

      if (response.statusCode == 200) {
        await StorageService.clearAll();
        return ApiResult.success(true);
      } else {
        return ApiResult.failure('Error al desactivar cuenta');
      }
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
      
    }
  }

  /// Cierra la sesion del usuario
  static Future<void> logout() async {
    await StorageService.clearAll();
  }
}
