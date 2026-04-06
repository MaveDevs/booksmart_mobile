import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

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

    debugPrint('[NotifScreen] Cargando notificaciones...');
    final result = await ApiService.getMyNotifications();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _notifications = result.data!;
          // Sincronizar conteo de no leídos con la realidad
          final unread = _notifications.where((n) => !n.leida).length;
          WebSocketService.instance.unreadCount.value = unread;
          debugPrint('[NotifScreen] ${_notifications.length} notificaciones cargadas, $unread no leídas');
        } else {
          _error = result.error;
          debugPrint('[NotifScreen] Error: ${result.error}');
        }
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.leida) return;

    final result =
        await ApiService.markNotificationRead(notification.notificacionId);
    if (result.success) {
      // También notificar vía WS
      WebSocketService.instance.markRead(notification.notificacionId);

      setState(() {
        final idx = _notifications.indexOf(notification);
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

      // Decrementar el contador global
      final count = WebSocketService.instance.unreadCount.value;
      if (count > 0) {
        WebSocketService.instance.unreadCount.value = count - 1;
      }
    }
  }

  IconData _iconForType(String tipo) {
    return switch (tipo) {
      'mensaje'          => Icons.chat_bubble_outline_rounded,
      'cita_confirmada'  => Icons.check_circle_outline_rounded,
      'cita_cancelada'   => Icons.cancel_outlined,
      'cita_completada'  => Icons.task_alt_rounded,
      _                  => Icons.notifications_outlined,
    };
  }

  Color _colorForType(String tipo) {
    return switch (tipo) {
      'mensaje'          => AppColors.primary,
      'cita_confirmada'  => AppColors.success,
      'cita_cancelada'   => AppColors.error,
      'cita_completada'  => AppColors.primary,
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
                          return _NotificationTile(
                            notification: n,
                            icon: _iconForType(n.tipo),
                            color: _colorForType(n.tipo),
                            timeAgo: _formatDate(n.fechaCreacion),
                            onTap: () => _markAsRead(n),
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
