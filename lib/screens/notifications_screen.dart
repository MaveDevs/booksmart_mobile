import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import 'appointment_chat_screen.dart';

/// Pantalla de notificaciones in-app
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getMyNotifications();
    final dismissedIds = await StorageService.getDismissedNotificationIds();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          // Filtrar las notificaciones descartadas por el usuario
          _notifications = result.data!
              .where((n) => !dismissedIds.contains(n.notificacionId))
              .toList();
          final unread = _notifications.where((n) => !n.leida).length;
          WebSocketService.instance.unreadCount.value = unread;
        } else {
          _error = result.error;
        }
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.leida) return;

    final result =
        await ApiService.markNotificationRead(notification.notificacionId);

    if (!mounted) return;

    if (result.success) {
      WebSocketService.instance.markRead(notification.notificacionId);

      setState(() {
        final idx = _notifications.indexWhere(
            (n) => n.notificacionId == notification.notificacionId);
        if (idx != -1) {
          _notifications[idx] = NotificationModel(
            notificacionId: notification.notificacionId,
            usuarioId: notification.usuarioId,
            tipo: notification.tipo,
            contenido: notification.contenido,
            leida: true,
            fechaCreacion: notification.fechaCreacion,
            citaId: notification.citaId,
          );
        }
      });

      final count = WebSocketService.instance.unreadCount.value;
      if (count > 0) {
        WebSocketService.instance.unreadCount.value = count - 1;
      }
    } else {
      debugPrint('[Notifications] Error marcando como leída: ${result.error}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Error al marcar como leída'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Maneja el tap sobre una notificación: marcar como leída + navegar
  Future<void> _onNotificationTap(NotificationModel notification) async {
    // Marcar como leída primero
    await _markAsRead(notification);
    if (!mounted) return;

    final tipo = notification.tipo.toUpperCase();
    debugPrint('[Notifications] Tap: tipo=$tipo citaId=${notification.citaId}');

    // Notificación de mensaje con cita_id → ir al chat de esa cita
    if (notification.citaId != null) {
      final result = await ApiService.getMyAppointments();
      if (!mounted) return;
      if (result.success && result.data != null) {
        final appointment = result.data!
            .where((a) => a.citaId == notification.citaId)
            .firstOrNull;
        if (appointment != null) {
          if (tipo.contains('MENSAJE') || tipo == 'INFO') {
            // Abrir chat de esa cita
            Navigator.push(
              context,
              appRoute(AppointmentChatScreen(appointment: appointment)),
            );
            return;
          } else {
            // Notificación de cita → ir a pestaña Citas
            Navigator.pop(context, 'appointments');
            return;
          }
        }
      }
    }

    // Sin cita_id: si es tipo cita, ir a pestaña Citas
    if (tipo.contains('CITA') || tipo == 'CONFIRMADA' || tipo == 'CANCELADA' || tipo == 'COMPLETADA') {
      Navigator.pop(context, 'appointments');
      return;
    }

    // Para tipo MENSAJE sin cita_id: ir a pestaña Citas (donde están los chats)
    if (tipo.contains('MENSAJE')) {
      Navigator.pop(context, 'appointments');
      return;
    }
  }

  Future<void> _markAllAsRead() async {
    final unread = _notifications.where((n) => !n.leida).toList();
    if (unread.isEmpty) return;

    // Marcar todas en paralelo
    final results = await Future.wait(
      unread.map((n) => ApiService.markNotificationRead(n.notificacionId)),
    );

    final allSuccess = results.every((r) => r.success);
    final successCount = results.where((r) => r.success).length;

    if (mounted) {
      if (allSuccess) {
        setState(() {
          _notifications = _notifications.map((n) {
            if (!n.leida) {
              return NotificationModel(
                notificacionId: n.notificacionId,
                usuarioId: n.usuarioId,
                tipo: n.tipo,
                contenido: n.contenido,
                leida: true,
                fechaCreacion: n.fechaCreacion,
                citaId: n.citaId,
              );
            }
            return n;
          }).toList();
        });
        WebSocketService.instance.unreadCount.value = 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Todas las notificaciones marcadas como leídas'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        debugPrint('[Notifications] markAllAsRead: $successCount/${unread.length} exitosas');
        // Recargar para reflejar el estado real del backend
        await _loadNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al marcar algunas notificaciones ($successCount/${unread.length} exitosas)'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _removeNotification(NotificationModel notification) async {
    // Marcar como leída si no lo está, luego quitar de la lista
    if (!notification.leida) {
      final result = await ApiService.markNotificationRead(notification.notificacionId);
      debugPrint('[Notifications] removeNotification markRead: success=${result.success}');
      final count = WebSocketService.instance.unreadCount.value;
      if (count > 0) {
        WebSocketService.instance.unreadCount.value = count - 1;
      }
    }
    // Persistir el ID como descartado para que no reaparezca
    await StorageService.dismissNotification(notification.notificacionId);
    if (mounted) {
      setState(() {
        _notifications.removeWhere(
            (n) => n.notificacionId == notification.notificacionId);
      });
    }
  }

  Future<void> _clearAllNotifications() async {
    if (_notifications.isEmpty) return;

    // Marcar todas como leídas y persistir como descartadas
    final allIds = _notifications.map((n) => n.notificacionId).toList();
    final unread = _notifications.where((n) => !n.leida).toList();

    // Await las llamadas para asegurar que se marcan en el backend
    if (unread.isNotEmpty) {
      await Future.wait(
        unread.map((n) => ApiService.markNotificationRead(n.notificacionId)),
      );
    }
    await StorageService.dismissNotifications(allIds);
    WebSocketService.instance.unreadCount.value = 0;

    if (mounted) {
      setState(() {
        _notifications.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notificaciones eliminadas'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showOptionsMenu() {
    final hasUnread = _notifications.any((n) => !n.leida);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (hasUnread)
              ListTile(
                leading: Icon(Icons.done_all_rounded, color: AppColors.primary),
                title: Text(
                  'Marcar todas como leídas',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _markAllAsRead();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              title: Text(
                'Borrar todas las notificaciones',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(context);
                _clearAllNotifications();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String tipo) {
    return switch (tipo.toUpperCase()) {
      'MENSAJE'          => Icons.chat_bubble_outline_rounded,
      'CITA_CONFIRMADA'  => Icons.check_circle_outline_rounded,
      'CITA_CANCELADA'   => Icons.cancel_outlined,
      'CITA_COMPLETADA'  => Icons.task_alt_rounded,
      'INFO'             => Icons.info_outline_rounded,
      'WARNING'          => Icons.warning_amber_rounded,
      'ERROR'            => Icons.error_outline_rounded,
      _                  => Icons.notifications_outlined,
    };
  }

  Color _colorForType(String tipo) {
    return switch (tipo.toUpperCase()) {
      'MENSAJE'          => AppColors.primary,
      'CITA_CONFIRMADA'  => AppColors.success,
      'CITA_CANCELADA'   => AppColors.error,
      'CITA_COMPLETADA'  => AppColors.primary,
      'INFO'             => AppColors.primary,
      'WARNING'          => AppColors.pending,
      'ERROR'            => AppColors.error,
      _                  => AppColors.pending,
    };
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Ahora';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNotifications = _notifications.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notificaciones',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading && hasNotifications)
            IconButton(
              icon: Icon(Icons.more_vert_rounded,
                  color: AppColors.textPrimary, size: 22),
              onPressed: _showOptionsMenu,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.grey),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _notifications.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return Dismissible(
                            key: ValueKey(n.notificacionId),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _removeNotification(n),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: AppColors.error.withValues(alpha: 0.8),
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            child: _NotificationTile(
                              notification: n,
                              icon: _iconForType(n.tipo),
                              color: _colorForType(n.tipo),
                              timeAgo: _formatDate(n.fechaCreacion),
                              onTap: () => _onNotificationTap(n),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 56, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'No tienes notificaciones',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Error al cargar',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final IconData icon;
  final Color color;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.color,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.leida;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primarySoft.withValues(alpha: 0.3)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: AppColors.grey, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),

            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.contenido,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Indicador de no leída
            if (isUnread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
