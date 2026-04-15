import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import '../config/api_config.dart';
import '../main.dart' show navigatorKey;
import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../models/establishment_model.dart';
import '../models/service_model.dart';
import '../models/rating_model.dart';
import '../models/appointment_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/worker_model.dart';
import '../screens/login_screen.dart';
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
  /// Evita que múltiples 401 simultáneos abran varias pantallas de login
  static bool _isHandlingSessionExpired = false;

  /// Maneja 401 globalmente: limpia sesión y redirige al login
  static Future<void> _handleSessionExpired() async {
    if (_isHandlingSessionExpired) return;
    _isHandlingSessionExpired = true;
    await StorageService.clearAll();
    final ctx = navigatorKey.currentState;
    if (ctx != null) {
      ctx.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
    _isHandlingSessionExpired = false;
  }

  /// Ejecuta una petición autenticada. Si recibe 401, limpia sesión y redirige.
  static Future<http.Response?> _authenticatedRequest(
    Future<http.Response> Function(String token) request,
  ) async {
    final token = await StorageService.getToken();
    if (token == null) {
      await _handleSessionExpired();
      return null;
    }
    try {
      final response = await request(token).timeout(Duration(seconds: ApiConfig.timeout));
      if (response.statusCode == 401) {
        await _handleSessionExpired();
        return null;
      }
      return response;
    } on SocketException {
      return null; // manejado en el caller
    }
  }
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
      } else if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 404) {
        return ApiResult.failure('Correo o contraseña incorrectos. Por favor, verifica tus datos.');
      } else {
        return ApiResult.failure('Error del servidor (${response.statusCode}). Intenta de nuevo más tarde.');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexión a internet. Verifica tu red e intenta de nuevo.');
    } on TimeoutException {
      return ApiResult.failure('El servidor no responde. Intenta de nuevo más tarde.');
    } on http.ClientException {
      return ApiResult.failure('Error de conexión. Verifica que tengas acceso a internet.');
    } catch (e) {
      return ApiResult.failure('Error inesperado. Intenta de nuevo.');
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
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.userEndpoint}/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(data);
        return ApiResult.success(user);
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
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(UserModel.fromJson(data));
      } else {
        return ApiResult.failure('Error al obtener usuario');
      }
    } on SocketException {
      return ApiResult.failure("Sin Conexion a Internet");
    } 
    catch (e) {
      return ApiResult.failure("Error inesperado: $e");
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
      final Map<String, dynamic> body = {};
      if (nombre != null) body ['nombre'] = nombre;
      if (apellido != null) body ['apellido'] = apellido;
      if (correo != null) body ['correo'] = correo;
      if (contrasena != null) body ['contrasena'] = contrasena;

      final response = await _authenticatedRequest((token) => http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(UserModel.fromJson(data));
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
      final response = await _authenticatedRequest((token) => http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'activo': false}),
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

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
    // Importación dinámica — cancelar tareas de background
    try {
      final Workmanager workmanager = Workmanager();
      await workmanager.cancelAll();
    } catch (_) {}
    await StorageService.clearAll();
  }

  /// Obtiene todos los establecimientos activos
  static Future<ApiResult<List<EstablishmentModel>>> getEstablishments() async {
    try {
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.establishmentsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final establishments = data
            .map((json) => EstablishmentModel.fromJson(json))
            .where((e) => e.activo)
            .toList();
        return ApiResult.success(establishments);
      } else {
        return ApiResult.failure('Error al obtener establecimientos');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Obtiene establecimientos cercanos ordenados por distancia y prioridad
  static Future<ApiResult<List<EstablishmentModel>>> getNearbyEstablishments({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    try {
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/establishments/nearby'
          '?latitude=$latitude&longitude=$longitude&radius_km=$radiusKm',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final establishments = data
            .map((json) => EstablishmentModel.fromJson(json))
            .toList();
        return ApiResult.success(establishments);
      } else {
        return ApiResult.failure('Error al obtener establecimientos cercanos');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  SERVICIOS DE UN ESTABLECIMIENTO
  // ══════════════════════════════════════════════════════════

  /// Obtiene los servicios de un establecimiento
  static Future<ApiResult<List<ServiceModel>>> getServices(int establishmentId) async {
    try {
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/services/?establishment_id=$establishmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final services = data.map((json) => ServiceModel.fromJson(json)).toList();
        return ApiResult.success(services);
      } else {
        return ApiResult.failure('Error al obtener servicios');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  CALIFICACIONES / RESEÑAS
  // ══════════════════════════════════════════════════════════

  /// Obtiene las calificaciones de un establecimiento
  static Future<ApiResult<List<RatingModel>>> getRatings(int establishmentId) async {
    try {
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/ratings/?establecimiento_id=$establishmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final ratings = data.map((json) => RatingModel.fromJson(json)).toList();
        return ApiResult.success(ratings);
      } else {
        return ApiResult.failure('Error al obtener calificaciones');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Obtiene las reseñas del usuario autenticado
  static Future<ApiResult<List<RatingModel>>> getMyRatings() async {
    try {
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/ratings/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final ratings = data.map((json) => RatingModel.fromJson(json)).toList();
        return ApiResult.success(ratings);
      } else {
        return ApiResult.failure('Error al obtener reseñas');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Crea una nueva reseña
  static Future<ApiResult<RatingModel>> createRating({
    required int establecimientoId,
    required int usuarioId,
    required int calificacion,
    String? comentario,
  }) async {
    try {
      final body = <String, dynamic>{
        'establecimiento_id': establecimientoId,
        'usuario_id': usuarioId,
        'calificacion': calificacion,
      };
      if (comentario != null && comentario.isNotEmpty) {
        body['comentario'] = comentario;
      }

      final response = await _authenticatedRequest((token) => http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/ratings/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResult.success(RatingModel.fromJson(data));
      } else if (response.statusCode == 400 || response.statusCode == 409) {
        final detail = _extractDetail(response.body);
        return ApiResult.failure(detail ?? 'Ya calificaste este establecimiento');
      } else {
        return ApiResult.failure('Error al enviar reseña');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  TRABAJADORES / WORKERS
  // ══════════════════════════════════════════════════════════

  /// Obtiene los trabajadores de un establecimiento
  static Future<ApiResult<List<WorkerModel>>> getWorkers(int establishmentId, {int? servicioId}) async {
    try {
      var url = '${ApiConfig.baseUrl}/api/v1/workers/?establishment_id=$establishmentId';
      if (servicioId != null) url += '&servicio_id=$servicioId';
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final workers = data
            .map((json) => WorkerModel.fromJson(json))
            .where((w) => w.activo)
            .toList();
        return ApiResult.success(workers);
      } else {
        return ApiResult.failure('Error al obtener profesionales');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  CITAS / APPOINTMENTS
  // ══════════════════════════════════════════════════════════

  /// Obtiene los slots disponibles para un servicio en una fecha
  static Future<ApiResult<List<String>>> getAvailableSlots({
    required int servicioId,
    required String fecha,
    int? trabajadorId,
  }) async {
    try {
      var url = '${ApiConfig.baseUrl}/api/v1/appointments/availability/slots'
          '?servicio_id=$servicioId&target_date=$fecha';
      if (trabajadorId != null) {
        url += '&trabajador_id=$trabajadorId';
      }
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final List<dynamic> data = body['available_slots'] ?? [];
        final slots = data.map((e) => e.toString()).toList();
        return ApiResult.success(slots);
      } else if (response.statusCode == 400) {
        final detail = _extractDetail(response.body);
        return ApiResult.failure(detail ?? 'No hay profesionales para este servicio');
      } else if (response.statusCode == 404) {
        return ApiResult.failure('Servicio no encontrado');
      } else {
        return ApiResult.failure('Error al obtener horarios');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Crea una nueva cita
  static Future<ApiResult<AppointmentModel>> createAppointment({
    required int clienteId,
    required int servicioId,
    required String fecha,
    required String horaInicio,
    required String horaFin,
    int? trabajadorId,
  }) async {
    try {
      final response = await _authenticatedRequest((token) => http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/appointments/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'cliente_id': clienteId,
          'servicio_id': servicioId,
          'fecha': fecha,
          'hora_inicio': horaInicio,
          'hora_fin': horaFin,
          'trabajador_id': trabajadorId,
        }),
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResult.success(AppointmentModel.fromJson(data));
      } else if (response.statusCode == 400) {
        final detail = _extractDetail(response.body);
        return ApiResult.failure(detail ?? 'No hay profesionales disponibles en este horario');
      } else if (response.statusCode == 409) {
        return ApiResult.failure('Ese horario ya no está disponible');
      } else {
        return ApiResult.failure('Error al crear cita');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Obtiene las citas del usuario autenticado
  static Future<ApiResult<List<AppointmentModel>>> getMyAppointments() async {
    try {
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/appointments/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final appointments = data.map((json) => AppointmentModel.fromJson(json)).toList();
        return ApiResult.success(appointments);
      } else {
        return ApiResult.failure('Error al obtener citas');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Cancela una cita (PATCH estado → CANCELADA)
  static Future<ApiResult<AppointmentModel>> cancelAppointment(int appointmentId) async {
    try {
      final response = await _authenticatedRequest((token) => http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/appointments/$appointmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'estado': 'CANCELADA'}),
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(AppointmentModel.fromJson(data));
      } else {
        return ApiResult.failure('Error al cancelar cita');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  MENSAJES / CHAT EN CONTEXTO DE CITA
  // ══════════════════════════════════════════════════════════

  /// Extrae el detalle de un error de la API
  static String? _extractDetail(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail[0]['msg'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Obtiene los mensajes de una cita
  static Future<ApiResult<List<MessageModel>>> getMessages(int citaId) async {
    try {
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/messages/?cita_id=$citaId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((json) => MessageModel.fromJson(json)).toList();
        return ApiResult.success(messages);
      } else {
        return ApiResult.failure('Error al obtener mensajes');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Envía un mensaje en el contexto de una cita
  static Future<ApiResult<MessageModel>> sendMessage({
    required int citaId,
    required int emisorId,
    required String contenido,
  }) async {
    try {
      final response = await _authenticatedRequest((token) => http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/messages/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'cita_id': citaId,
          'emisor_id': emisorId,
          'contenido': contenido,
        }),
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResult.success(MessageModel.fromJson(data));
      } else {
        final detail = _extractDetail(response.body);
        return ApiResult.failure(detail ?? 'Error al enviar mensaje');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  NOTIFICACIONES
  // ══════════════════════════════════════════════════════════

  /// Obtiene las notificaciones del usuario autenticado
  static Future<ApiResult<List<NotificationModel>>> getMyNotifications() async {
    try {
      final response = await _authenticatedRequest((token) => http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/notifications/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) return ApiResult.failure('Sesion expirada');

      debugPrint('[Notifications] GET /notifications/me/ status: ${response.statusCode}');
      debugPrint('[Notifications] GET /notifications/me/ body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final notifications =
            data.map((json) => NotificationModel.fromJson(json)).toList();
        debugPrint('[Notifications] Parsed ${notifications.length} notifications, ${notifications.where((n) => !n.leida).length} unread');
        return ApiResult.success(notifications);
      } else {
        return ApiResult.failure('Error al obtener notificaciones (${response.statusCode})');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      debugPrint('[Notifications] Error: $e');
      return ApiResult.failure('Error inesperado: $e');
    }
  }

  /// Marca una notificación como leída
  static Future<ApiResult<bool>> markNotificationRead(int notificationId) async {
    try {
      final url = '${ApiConfig.baseUrl}/api/v1/notifications/$notificationId';
      debugPrint('[Notifications] PATCH $url body: {"leida": true}');

      final response = await _authenticatedRequest((token) => http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'leida': true}),
      ));

      if (response == null) {
        debugPrint('[Notifications] PATCH markRead: response null (sesion expirada)');
        return ApiResult.failure('Sesion expirada');
      }

      debugPrint('[Notifications] PATCH markRead status: ${response.statusCode} body: ${response.body}');

      if (response.statusCode == 200) {
        return ApiResult.success(true);
      } else {
        return ApiResult.failure('Error al marcar notificacion (${response.statusCode})');
      }
    } on SocketException {
      return ApiResult.failure('Sin conexion a internet');
    } catch (e) {
      return ApiResult.failure('Error inesperado: $e');
    }
  }
}
