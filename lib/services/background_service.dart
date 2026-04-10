import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import '../config/api_config.dart';

/// Nombre de la tarea periódica en background
const String backgroundNotificationTask = 'checkNotifications';

/// Callback que se ejecuta en un isolate separado (incluso con la app cerrada).
/// No tiene acceso a las clases de servicio normales (ApiService, StorageService),
/// así que hace las llamadas HTTP directamente.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[BG] Tarea ejecutada: $taskName');

    if (taskName != backgroundNotificationTask) return true;

    try {
      const storage = FlutterSecureStorage();

      // Leer token y último ID conocido
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        debugPrint('[BG] Sin token — ignorando');
        return true;
      }

      final lastIdStr = await storage.read(key: 'bg_last_notif_id');
      final lastId = int.tryParse(lastIdStr ?? '0') ?? 0;

      // GET /api/v1/notifications/me/
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/notifications/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[BG] API status: ${response.statusCode}');
        return true;
      }

      final List<dynamic> data = jsonDecode(response.body);

      // Filtrar nuevas no leídas
      final newNotifs = data.where((n) {
        final id = n['notificacion_id'] as int? ?? 0;
        final leida = n['leida'] as bool? ?? true;
        return !leida && id > lastId;
      }).toList();

      if (newNotifs.isEmpty) {
        debugPrint('[BG] Sin notificaciones nuevas');
        return true;
      }

      debugPrint('[BG] ${newNotifs.length} notificaciones nuevas');

      // Inicializar plugin de notificaciones locales
      final plugin = FlutterLocalNotificationsPlugin();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await plugin.initialize(settings);

      // Mostrar cada notificación
      for (final n in newNotifs) {
        final id = n['notificacion_id'] as int? ?? 0;
        final mensaje = n['mensaje'] as String? ?? 'Nueva notificación';
        final tipo = (n['tipo'] as String? ?? '').toUpperCase();

        final title = switch (tipo) {
          'MENSAJE'         => 'Nuevo mensaje',
          'CITA_CONFIRMADA' => 'Cita confirmada',
          'CITA_CANCELADA'  => 'Cita cancelada',
          'CITA_COMPLETADA' => 'Cita completada',
          'INFO'            => 'Información',
          'WARNING'         => 'Advertencia',
          'ERROR'           => 'Error',
          _                 => 'BookSmart',
        };

        final androidDetails = AndroidNotificationDetails(
          'background',
          'Notificaciones',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

        await plugin.show(
          id % 2147483647,
          title,
          mensaje,
          NotificationDetails(android: androidDetails),
        );
      }

      // Actualizar último ID conocido
      final maxId = newNotifs
          .map((n) => n['notificacion_id'] as int? ?? 0)
          .reduce((a, b) => a > b ? a : b);
      if (maxId > lastId) {
        await storage.write(key: 'bg_last_notif_id', value: maxId.toString());
      }
    } on SocketException {
      debugPrint('[BG] Sin conexión a internet');
    } catch (e) {
      debugPrint('[BG] Error: $e');
    }

    return true;
  });
}

/// Inicializa y registra la tarea periódica de background
class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> startPeriodicCheck() async {
    // Sincronizar el último ID conocido para el background worker
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null) return;

    // Registrar tarea periódica — mínimo 15 minutos en Android
    await Workmanager().registerPeriodicTask(
      'notif-check',
      backgroundNotificationTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
    debugPrint('[BG] Tarea periódica registrada (cada ~15 min)');
  }

  static Future<void> stop() async {
    await Workmanager().cancelAll();
    debugPrint('[BG] Tareas canceladas');
  }
}
