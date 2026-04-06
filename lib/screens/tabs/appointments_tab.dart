import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/appointment_model.dart';
import '../../services/api_service.dart';
import '../appointment_chat_screen.dart';

/// Tab de citas agendadas — conectado a la API
class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getMyAppointments();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _appointments = result.data!;
        } else {
          _error = result.error;
        }
      });
    }
  }

  void _openChat(AppointmentModel appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentChatScreen(appointment: appointment),
      ),
    );
  }

  Future<void> _cancelAppointment(AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancelar cita',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '¿Estás seguro de que deseas cancelar esta cita?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.cancelAppointment(appointment.citaId);
    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cita cancelada'),
            backgroundColor: AppColors.primary,
          ),
        );
        _loadAppointments(); // Recargar lista
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Error al cancelar')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mis Citas',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revisa el estado de tus citas agendadas',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _error != null
                      ? _buildErrorState()
                      : _appointments.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: _loadAppointments,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 0, 24, 100),
                                itemCount: _appointments.length,
                                itemBuilder: (context, index) {
                                  return _AppointmentCard(
                                    appointment: _appointments[index],
                                    onCancel: _cancelAppointment,
                                    onChat: _openChat,
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes citas agendadas',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Busca un servicio para agendar',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: AppColors.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Error al cargar citas',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

/// Card de una cita
class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final void Function(AppointmentModel) onCancel;
  final void Function(AppointmentModel) onChat;

  const _AppointmentCard({
    required this.appointment,
    required this.onCancel,
    required this.onChat,
  });

  Color _statusColor() {
    switch (appointment.estado) {
      case 'CONFIRMADA':
        return AppColors.success;
      case 'PENDIENTE':
        return AppColors.pending;
      case 'CANCELADA':
        return AppColors.error;
      case 'COMPLETADA':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon() {
    switch (appointment.estado) {
      case 'CONFIRMADA':
        return Icons.check_circle_outline;
      case 'PENDIENTE':
        return Icons.schedule_outlined;
      case 'CANCELADA':
        return Icons.cancel_outlined;
      case 'COMPLETADA':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.greyDark,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del establecimiento y estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  appointment.establecimientoNombre ?? 'Establecimiento',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(), size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      appointment.estadoDisplay,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Servicio
          Row(
            children: [
              Icon(Icons.content_cut_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appointment.servicioNombre ?? 'Servicio #${appointment.servicioId}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fecha y hora
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 16, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Text(
                '${appointment.fecha}  •  ${appointment.horarioDisplay}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // Botones de acción
          if (appointment.canCancel || !appointment.isCancelada) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botón chat (disponible si no está cancelada)
                if (!appointment.isCancelada)
                  GestureDetector(
                    onTap: () => onChat(appointment),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Chat',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!appointment.isCancelada && appointment.canCancel)
                  const SizedBox(width: 10),
                // Botón cancelar
                if (appointment.canCancel)
                  GestureDetector(
                    onTap: () => onCancel(appointment),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
