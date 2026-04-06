import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'websocket_service.dart';

/// Servicio de notificaciones locales del dispositivo.
/// Escucha eventos del WebSocket y muestra notificaciones push locales.
/// También hace polling periódico para detectar nuevas notificaciones.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription<WsEvent>? _subscription;
  static Timer? _pollTimer;
  static int _lastKnownNotificationId = 0;

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

    // Polling cada 30s para detectar nuevas notificaciones
    // (funciona como fallback cuando WS no está conectado)
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      debugPrint('[LocalNotif] Poll tick — verificando nuevas notificaciones');
      _checkForNewNotifications();
    });

    // Cargar el último ID conocido
    _initLastKnownId();
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Carga el ID más alto de las notificaciones actuales
  static Future<void> _initLastKnownId() async {
    try {
      final result = await ApiService.getMyNotifications();
      if (result.success && result.data != null && result.data!.isNotEmpty) {
        _lastKnownNotificationId = result.data!
            .map((n) => n.notificacionId)
            .reduce((a, b) => a > b ? a : b);
        debugPrint('[LocalNotif] lastKnownId=$_lastKnownNotificationId (${result.data!.length} notificaciones)');
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

      debugPrint('[LocalNotif] Poll: ${result.data!.length} total, lastKnownId=$_lastKnownNotificationId');

      final newUnread = result.data!
          .where((n) => !n.leida && n.notificacionId > _lastKnownNotificationId)
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
        }
      }
    } catch (e) {
      debugPrint('[LocalNotif] Error polling: $e');
    }
  }

  static String _channelForType(String tipo) {
    if (tipo.contains('mensaje')) return 'messages';
    if (tipo.contains('cita')) return 'appointments';
    return 'general';
  }

  static String _channelNameForType(String tipo) {
    if (tipo.contains('mensaje')) return 'Mensajes';
    if (tipo.contains('cita')) return 'Citas';
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
          body: event.data['contenido'] as String? ?? 'Nueva notificación',
          channel: 'general',
          channelName: 'Notificaciones',
        );
        break;

      default:
        break;
    }
  }

  static String _notificationTitle(String tipo) {
    return switch (tipo) {
      'mensaje'          => 'Nuevo mensaje',
      'cita_confirmada'  => 'Cita confirmada',
      'cita_cancelada'   => 'Cita cancelada',
      'cita_completada'  => 'Cita completada',
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
