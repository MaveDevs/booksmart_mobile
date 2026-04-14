import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/appointment_model.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'websocket_service.dart';

/// Servicio de notificaciones locales del dispositivo.
/// Escucha eventos del WebSocket y muestra notificaciones push locales.
/// También hace polling periódico para detectar nuevas notificaciones,
/// cambios de estado en citas y nuevos mensajes.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription<WsEvent>? _subscription;
  static Timer? _pollTimer;
  static int _lastKnownNotificationId = 0;

  // Tracking de estados de citas para detectar cambios
  static Map<int, String> _appointmentStates = {};
  static bool _appointmentStatesInitialized = false;

  /// Inicializa el plugin de notificaciones locales
  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings);

    // Solicitar permisos en Android 13+
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Comienza a escuchar eventos del WebSocket y poll API para notificaciones
  static void startListening() {
    debugPrint('[LocalNotif] startListening() llamado');
    _subscription?.cancel();
    _subscription = WebSocketService.instance.events.listen(_handleEvent);

    // Polling cada 30s para detectar nuevas notificaciones y cambios en citas
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      debugPrint('[LocalNotif] Poll tick — verificando cambios');
      _checkForNewNotifications();
      _checkForAppointmentChanges();
    });

    // Cargar el último ID conocido y estados iniciales
    _initLastKnownId();
    _initAppointmentStates();
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _appointmentStates.clear();
    _appointmentStatesInitialized = false;
  }

  /// Carga el ID más alto de las notificaciones actuales.
  /// Primero intenta leer el último ID conocido del storage persistente;
  /// si no existe (primera vez), usa el máximo actual sin notificar.
  /// Si existe, verifica inmediatamente si hay nuevas notificaciones.
  static Future<void> _initLastKnownId() async {
    try {
      // Intentar cargar del storage persistente (de la sesión anterior)
      final stored = await StorageService.read('bg_last_notif_id');
      if (stored != null) {
        _lastKnownNotificationId = int.tryParse(stored) ?? 0;
        debugPrint('[LocalNotif] lastKnownId from storage: $_lastKnownNotificationId');
        // Verificar inmediatamente si hay notificaciones nuevas
        await _checkForNewNotifications();
        return;
      }

      // Primera vez: establecer al máximo actual sin notificar
      final result = await ApiService.getMyNotifications();
      if (result.success && result.data != null && result.data!.isNotEmpty) {
        _lastKnownNotificationId = result.data!
            .map((n) => n.notificacionId)
            .reduce((a, b) => a > b ? a : b);
        await StorageService.write('bg_last_notif_id', _lastKnownNotificationId.toString());
        debugPrint('[LocalNotif] lastKnownId (first time)=$_lastKnownNotificationId (${result.data!.length} notificaciones)');
      } else {
        debugPrint('[LocalNotif] _initLastKnownId: sin notificaciones previas (success=${result.success}, data=${result.data?.length ?? 0}, error=${result.error})');
      }
    } catch (e) {
      debugPrint('[LocalNotif] Error en _initLastKnownId: $e');
    }
  }

  /// Verifica si hay nuevas notificaciones no leídas vía REST API
  static Future<void> _checkForNewNotifications() async {
    try {
      final result = await ApiService.getMyNotifications();
      if (!result.success || result.data == null) {
        debugPrint('[LocalNotif] Poll: API error=${result.error}');
        return;
      }

      final dismissedIds = await StorageService.getDismissedNotificationIds();

      debugPrint('[LocalNotif] Poll: ${result.data!.length} total, lastKnownId=$_lastKnownNotificationId, dismissed=${dismissedIds.length}');

      final newUnread = result.data!
          .where((n) => !n.leida
              && n.notificacionId > _lastKnownNotificationId
              && !dismissedIds.contains(n.notificacionId))
          .toList();

      debugPrint('[LocalNotif] Poll: ${newUnread.length} nuevas no leídas');

      for (final n in newUnread) {
        debugPrint('[LocalNotif] Mostrando push: id=${n.notificacionId} tipo=${n.tipo} contenido=${n.contenido}');
        _showNotification(
          id: n.notificacionId,
          title: _notificationTitle(n.tipo),
          body: n.contenido,
          channel: _channelForType(n.tipo),
          channelName: _channelNameForType(n.tipo),
        );
      }

      // Actualizar el último ID conocido
      if (result.data!.isNotEmpty) {
        final maxId = result.data!
            .map((n) => n.notificacionId)
            .reduce((a, b) => a > b ? a : b);
        if (maxId > _lastKnownNotificationId) {
          _lastKnownNotificationId = maxId;
          // Sincronizar con el worker de background
          StorageService.write('bg_last_notif_id', maxId.toString());
        }
      }
    } catch (e) {
      debugPrint('[LocalNotif] Error polling: $e');
    }
  }

  /// Carga los estados iniciales de las citas (sin notificar)
  static Future<void> _initAppointmentStates() async {
    try {
      final result = await ApiService.getMyAppointments();
      if (result.success && result.data != null) {
        _appointmentStates = {
          for (final a in result.data!) a.citaId: a.estado,
        };
        _appointmentStatesInitialized = true;
        debugPrint('[LocalNotif] Citas inicializadas: ${_appointmentStates.length}');
      }
    } catch (e) {
      debugPrint('[LocalNotif] Error inicializando citas: $e');
    }
  }

  /// Detecta cambios de estado en citas y notifica
  static Future<void> _checkForAppointmentChanges() async {
    if (!_appointmentStatesInitialized) return;

    try {
      final result = await ApiService.getMyAppointments();
      if (!result.success || result.data == null) return;

      for (final appointment in result.data!) {
        final prevState = _appointmentStates[appointment.citaId];

        if (prevState != null && prevState != appointment.estado) {
          // El estado cambió — notificar
          final title = _appointmentStatusTitle(appointment.estado);
          final body = _appointmentStatusBody(appointment);
          debugPrint('[LocalNotif] Cita ${appointment.citaId}: $prevState → ${appointment.estado}');

          _showNotification(
            id: 100000 + appointment.citaId, // offset para no colisionar con notif IDs
            title: title,
            body: body,
            channel: 'appointments',
            channelName: 'Citas',
          );
        } else if (prevState == null) {
          // Cita nueva que no teníamos — no notificar, solo registrar
          debugPrint('[LocalNotif] Nueva cita detectada: ${appointment.citaId} (${appointment.estado})');
        }
      }

      // Actualizar estados
      _appointmentStates = {
        for (final a in result.data!) a.citaId: a.estado,
      };
    } catch (e) {
      debugPrint('[LocalNotif] Error verificando citas: $e');
    }
  }

  static String _appointmentStatusTitle(String estado) {
    return switch (estado.toUpperCase()) {
      'CONFIRMADA' => 'Cita confirmada',
      'CANCELADA'  => 'Cita cancelada',
      'COMPLETADA' => 'Cita completada',
      _            => 'Actualización de cita',
    };
  }

  static String _appointmentStatusBody(AppointmentModel a) {
    final fecha = _formatFecha(a.fecha);
    final hora = _formatHora(a.horaInicio);
    return switch (a.estado.toUpperCase()) {
      'CONFIRMADA' => 'Tu cita del $fecha a las $hora ha sido confirmada',
      'CANCELADA'  => 'Tu cita del $fecha a las $hora ha sido cancelada',
      'COMPLETADA' => 'Tu cita del $fecha a las $hora ha sido completada',
      _            => 'Tu cita del $fecha a las $hora fue actualizada',
    };
  }

  /// Convierte "2026-04-14" → "14/04/2026"
  static String _formatFecha(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  /// Convierte "10:00:00" o "14:30" → "10:00 AM" o "2:30 PM"
  static String _formatHora(String raw) {
    try {
      final parts = raw.split(':');
      int hour = int.parse(parts[0]);
      final min = parts.length > 1 ? parts[1] : '00';
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) hour = 12;
      if (hour > 12) hour -= 12;
      return '$hour:$min $period';
    } catch (_) {
      return raw;
    }
  }

  static String _channelForType(String tipo) {
    final t = tipo.toUpperCase();
    if (t.contains('MENSAJE')) return 'messages';
    if (t.contains('CITA')) return 'appointments';
    return 'general';
  }

  static String _channelNameForType(String tipo) {
    final t = tipo.toUpperCase();
    if (t.contains('MENSAJE')) return 'Mensajes';
    if (t.contains('CITA')) return 'Citas';
    return 'Notificaciones';
  }

  static void _handleEvent(WsEvent event) {
    debugPrint('[LocalNotif] WS event recibido: type=${event.type}, data=${event.data}');
    switch (event.type) {
      case WsEventType.message:
        _showNotification(
          id: event.data['mensaje_id'] as int? ?? DateTime.now().millisecond,
          title: 'Nuevo mensaje',
          body: event.data['contenido'] as String? ?? 'Tienes un nuevo mensaje',
          channel: 'messages',
          channelName: 'Mensajes',
        );
        break;

      case WsEventType.appointment:
        final estado = event.data['estado'] as String? ?? '';
        final title = switch (estado.toUpperCase()) {
          'CONFIRMADA' => 'Cita confirmada',
          'CANCELADA'  => 'Cita cancelada',
          'COMPLETADA' => 'Cita completada',
          _            => 'Actualización de cita',
        };
        _showNotification(
          id: event.data['cita_id'] as int? ?? DateTime.now().millisecond,
          title: title,
          body: event.data['contenido'] as String? ??
              'Tu cita ha sido actualizada',
          channel: 'appointments',
          channelName: 'Citas',
        );
        break;

      case WsEventType.notification:
        _showNotification(
          id: event.data['notificacion_id'] as int? ??
              event.data['id'] as int? ??
              DateTime.now().millisecond,
          title: _notificationTitle(event.data['tipo'] as String? ?? ''),
          body: event.data['mensaje'] as String? ??
              event.data['contenido'] as String? ??
              'Nueva notificación',
          channel: 'general',
          channelName: 'Notificaciones',
        );
        break;

      default:
        break;
    }
  }

  static String _notificationTitle(String tipo) {
    return switch (tipo.toUpperCase()) {
      'MENSAJE'          => 'Nuevo mensaje',
      'CITA_CONFIRMADA'  => 'Cita confirmada',
      'CITA_CANCELADA'   => 'Cita cancelada',
      'CITA_COMPLETADA'  => 'Cita completada',
      'INFO'             => 'Información',
      'WARNING'          => 'Advertencia',
      'ERROR'            => 'Error',
      _                  => 'BookSmart',
    };
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channel,
    required String channelName,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channel,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    try {
      await _plugin.show(id % 2147483647, title, body, details);
      debugPrint('[LocalNotif] Push mostrado: "$title" — "$body"');
    } catch (e) {
      debugPrint('[LocalNotif] Error mostrando push: $e');
    }
  }
}
