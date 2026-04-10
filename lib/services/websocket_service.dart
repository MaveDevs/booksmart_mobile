import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Tipos de eventos que recibimos del servidor
enum WsEventType { notification, message, appointment, ping, unknown }

/// Evento recibido por WebSocket
class WsEvent {
  final WsEventType type;
  final Map<String, dynamic> data;

  WsEvent({required this.type, required this.data});
}

/// Servicio de WebSocket para eventos en tiempo real.
/// Singleton — se conecta una vez y se reutiliza.
///
/// Independientemente del WS, mantiene polling de notificaciones
/// para funcionar aunque el WebSocket no esté disponible.
class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._();

  WebSocketService._();

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  bool _isConnected = false;
  bool _disposed = false;
  bool _pollingStarted = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 60;

  /// Stream público de eventos
  final _eventController = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get events => _eventController.stream;

  /// Contador de notificaciones no leídas (reactivo)
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  // ──────────────────────────────────────────────
  //  NOTIFICATION POLLING (independiente del WS)
  // ──────────────────────────────────────────────

  /// Inicia el sistema de polling de notificaciones.
  /// Se llama una vez al iniciar sesión. Funciona aunque el WS no conecte.
  void startNotificationPolling() {
    if (_pollingStarted) return;
    _pollingStarted = true;
    debugPrint('[Notifications] Iniciando polling de notificaciones');

    // Cargar conteo inmediatamente
    refreshUnreadCount();

    // Polling cada 30s
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshUnreadCount();
    });
  }

  /// Carga el conteo de notificaciones no leídas desde el REST API
  /// Filtra las notificaciones descartadas localmente por el usuario
  Future<void> refreshUnreadCount() async {
    try {
      final result = await ApiService.getMyNotifications();
      if (result.success && result.data != null) {
        final dismissedIds = await StorageService.getDismissedNotificationIds();
        final unread = result.data!
            .where((n) => !n.leida && !dismissedIds.contains(n.notificacionId))
            .length;
        debugPrint('[Notifications] Unread count from API: $unread (total: ${result.data!.length}, dismissed: ${dismissedIds.length})');
        unreadCount.value = unread;
      } else {
        debugPrint('[Notifications] API error: ${result.error}');
      }
    } catch (e) {
      debugPrint('[Notifications] Error cargando count: $e');
    }
  }

  // ──────────────────────────────────────────────
  //  WEBSOCKET CONNECTION
  // ──────────────────────────────────────────────

  /// Conecta al WebSocket del servidor
  Future<void> connect() async {
    if (_isConnected || _disposed) return;

    final token = await StorageService.getToken();
    if (token == null) return;

    // Siempre asegurar que el polling esté corriendo
    startNotificationPolling();

    final wsBase = ApiConfig.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse('$wsBase/api/v1/ws?token=$token'),
      );

      await channel.ready;
      _channel = channel;
      _isConnected = true;
      _reconnectAttempts = 0;
      debugPrint('[WS] Conectado exitosamente');

      _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          debugPrint('[WS] Stream error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WS] Desconectado');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _send({'type': 'ping'});
      });
    } catch (e) {
      debugPrint('[WS] Error de conexion: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final typeStr = data['type'] as String? ?? '';
      debugPrint('[WS] Mensaje recibido: type=$typeStr');

      final type = switch (typeStr) {
        'notification' => WsEventType.notification,
        'message'      => WsEventType.message,
        'appointment'  => WsEventType.appointment,
        'ping'         => WsEventType.ping,
        _              => WsEventType.unknown,
      };

      if (type == WsEventType.ping) return;

      final event = WsEvent(type: type, data: data);
      _eventController.add(event);

      // Incrementar badge y refrescar desde API
      if (type == WsEventType.notification ||
          type == WsEventType.message ||
          type == WsEventType.appointment) {
        unreadCount.value++;
        // También refrescar desde API para mantener sincronizado
        refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('[WS] Error parseando mensaje: $e');
    }
  }

  void _send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  /// Envía mark_read al servidor vía WS
  void markRead(int notificationId) {
    _send({'type': 'mark_read', 'id': notificationId});
  }

  void _scheduleReconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_disposed) return;

    final delay = min(5 * pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay);
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      debugPrint('[WS] Intentando reconectar (intento $_reconnectAttempts, delay ${delay}s)...');
      connect();
    });
  }

  /// Desconecta y libera recursos
  void disconnect() {
    _disposed = true;
    _pollingStarted = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  /// Reinicia la conexión (util después de login)
  Future<void> reconnect() async {
    _disposed = false;
    disconnect();
    _disposed = false;
    await connect();
  }
}
