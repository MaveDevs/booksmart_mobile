import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/page_transitions.dart';
import '../../models/appointment_model.dart';
import '../../services/api_service.dart';
import '../appointment_chat_screen.dart';
import '../rating_dialog.dart';

/// Información enriquecida de un servicio + su establecimiento
class _ServiceInfo {
  final int estId;
  final String estNombre;
  final String estDireccion;
  final String svcNombre;
  final double svcPrecio;
  final int svcDuracion;

  const _ServiceInfo({
    required this.estId,
    required this.estNombre,
    required this.estDireccion,
    required this.svcNombre,
    required this.svcPrecio,
    required this.svcDuracion,
  });
}

/// Tab de citas agendadas — conectado a la API
class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  List<AppointmentModel> _appointments = [];
  Set<int> _ratedEstablishmentIds = {};
  /// servicioId → info enriquecida del servicio y establecimiento
  Map<int, _ServiceInfo> _serviceInfoMap = {};
  int? _currentUserId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = await Future.wait([
      ApiService.getMyAppointments(),
      ApiService.getMyRatings(),
      ApiService.getCurrentUser(),
      ApiService.getEstablishments(),
    ]);

    if (!mounted) return;

    final appointmentsResult = results[0] as ApiResult<List<AppointmentModel>>;
    final ratingsResult = results[1] as ApiResult;
    final userResult = results[2] as ApiResult;
    final establishmentsResult = results[3] as ApiResult;

    // Construir mapa servicioId → info enriquecida
    Map<int, _ServiceInfo> infoMap = {};
    if (establishmentsResult.success && establishmentsResult.data != null) {
      final establishments = establishmentsResult.data as List;
      final serviceResults = await Future.wait([
        for (final e in establishments)
          ApiService.getServices(e.establecimientoId as int),
      ]);
      for (int i = 0; i < establishments.length; i++) {
        final est = establishments[i];
        final svcResult = serviceResults[i];
        if (svcResult.success && svcResult.data != null) {
          for (final svc in svcResult.data!) {
            infoMap[svc.servicioId] = _ServiceInfo(
              estId: est.establecimientoId as int,
              estNombre: est.nombre as String,
              estDireccion: est.direccion as String,
              svcNombre: svc.nombre,
              svcPrecio: svc.precio,
              svcDuracion: svc.duracion,
            );
          }
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (appointmentsResult.success && appointmentsResult.data != null) {
        _appointments = appointmentsResult.data!;
      } else {
        _error = appointmentsResult.error;
      }

      if (ratingsResult.success && ratingsResult.data != null) {
        final ratings = ratingsResult.data as List;
        _ratedEstablishmentIds =
            ratings.map((r) => r.establecimientoId as int).toSet();
      }

      if (userResult.success && userResult.data != null) {
        _currentUserId = (userResult.data as dynamic).usuarioId as int;
      }

      _serviceInfoMap = infoMap;
    });
  }

  Future<void> _rateAppointment(AppointmentModel appointment) async {
    final info = _serviceInfoMap[appointment.servicioId];
    final estId = appointment.establecimientoId ?? info?.estId;
    final estNombre =
        appointment.establecimientoNombre ?? info?.estNombre ?? 'Establecimiento';

    if (_currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Error: no se pudo obtener tu usuario. Intenta de nuevo.')),
        );
      }
      _loadData();
      return;
    }

    if (estId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: no se pudo determinar el establecimiento.')),
        );
      }
      return;
    }

    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => RatingDialog(
        establecimientoId: estId,
        usuarioId: _currentUserId!,
        establecimientoNombre: estNombre,
      ),
    );

    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Gracias por tu reseña!'),
          backgroundColor: AppColors.primary,
        ),
      );
      _loadData();
    }
  }

  void _openChat(AppointmentModel appointment) {
    Navigator.push(
      context,
      appRoute(AppointmentChatScreen(appointment: appointment)),
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
            child:
                const Text('Sí, cancelar', style: TextStyle(color: Colors.red)),
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
        _loadData();
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mis Citas',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                      ? _buildErrorState()
                      : _appointments.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: _loadData,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 100),
                                itemCount: _appointments.length,
                                itemBuilder: (context, index) {
                                  final appt = _appointments[index];
                                  final info =
                                      _serviceInfoMap[appt.servicioId];
                                  final resolvedEstId =
                                      appt.establecimientoId ?? info?.estId;
                                  final alreadyRated = resolvedEstId != null &&
                                      _ratedEstablishmentIds
                                          .contains(resolvedEstId);
                                  return _AppointmentCard(
                                    appointment: appt,
                                    serviceInfo: info,
                                    onCancel: _cancelAppointment,
                                    onChat: _openChat,
                                    onRate: _rateAppointment,
                                    showRateCta:
                                        appt.isCompletada && !alreadyRated,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tienes citas agendadas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Busca un servicio para agendar tu primera cita',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _error ?? 'Error al cargar citas',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers de formato de fecha en español ────────────────────────────

const _diasSemana = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
];
const _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];

/// "2026-04-06" → "Lunes 6 de Abril"
String _formatFechaLegible(String fecha) {
  try {
    final d = DateTime.parse(fecha);
    final dia = _diasSemana[d.weekday - 1];
    final mes = _meses[d.month - 1];
    return '$dia ${d.day} de $mes';
  } catch (_) {
    return fecha;
  }
}

/// "10:00" → "10:00 AM", "14:30" → "2:30 PM"
String _formatHora12(String hora) {
  try {
    final parts = hora.split(':');
    var h = int.parse(parts[0]);
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:$m $ampm';
  } catch (_) {
    return hora;
  }
}

// ─── Card de cita ─────────────────────────────────────────────────────

class _AppointmentCard extends StatefulWidget {
  final AppointmentModel appointment;
  final _ServiceInfo? serviceInfo;
  final void Function(AppointmentModel) onCancel;
  final void Function(AppointmentModel) onChat;
  final void Function(AppointmentModel) onRate;
  final bool showRateCta;

  const _AppointmentCard({
    required this.appointment,
    required this.serviceInfo,
    required this.onCancel,
    required this.onChat,
    required this.onRate,
    this.showRateCta = false,
  });

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.appointment.estado) {
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

  IconData get _statusIcon {
    switch (widget.appointment.estado) {
      case 'CONFIRMADA':
        return Icons.check_circle_rounded;
      case 'PENDIENTE':
        return Icons.schedule_rounded;
      case 'CANCELADA':
        return Icons.cancel_rounded;
      case 'COMPLETADA':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;
    final info = widget.serviceInfo;
    final color = _statusColor;

    final estNombre =
        appt.establecimientoNombre ?? info?.estNombre ?? 'Establecimiento';
    final svcNombre =
        appt.servicioNombre ?? info?.svcNombre ?? 'Servicio #${appt.servicioId}';
    final workerName = appt.trabajadorNombreCompleto;
    final direccion = info?.estDireccion;
    final fechaLegible = _formatFechaLegible(appt.fecha);
    final horaInicio = _formatHora12(appt.horaInicio);
    final horaFin = _formatHora12(appt.horaFin);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _expanded
              ? color.withValues(alpha: 0.4)
              : AppColors.greyDark,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fila superior: badge de estado ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, size: 14, color: color),
                          const SizedBox(width: 5),
                          Text(
                            appt.estadoDisplay,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Nombre del establecimiento ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.store_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            estNombre,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            svcNombre,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (workerName != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 13, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    workerName,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Fecha y hora ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            fechaLegible,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 18, color: AppColors.primaryLight),
                          const SizedBox(width: 10),
                          Text(
                            '$horaInicio - $horaFin',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Sección expandible ──
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildExpandedContent(
                    direccion: direccion,
                    info: info,
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                  sizeCurve: Curves.easeInOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent({
    required String? direccion,
    required _ServiceInfo? info,
  }) {
    final appt = widget.appointment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: AppColors.grey, height: 1),
        const SizedBox(height: 16),

        // Dirección
        if (direccion != null && direccion.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    direccion,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Precio y duración
        if (info != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                _InfoChip(
                  icon: Icons.attach_money_rounded,
                  label: '\$${info.svcPrecio.toStringAsFixed(2)}',
                ),
                const SizedBox(width: 10),
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: info.svcDuracion >= 60
                      ? '${info.svcDuracion ~/ 60}h ${info.svcDuracion % 60 > 0 ? '${info.svcDuracion % 60}min' : ''}'
                      : '${info.svcDuracion} min',
                ),
              ],
            ),
          ),

        // Botones de acción
        if (appt.canCancel || !appt.isCancelada || widget.showRateCta)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.showRateCta)
                _ActionButton(
                  icon: Icons.star_rounded,
                  label: 'Calificar',
                  color: AppColors.warning,
                  onTap: () => widget.onRate(appt),
                ),
              if (!appt.isCancelada)
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  color: AppColors.primary,
                  onTap: () => widget.onChat(appt),
                ),
              if (appt.canCancel)
                _ActionButton(
                  icon: Icons.close_rounded,
                  label: 'Cancelar',
                  color: AppColors.error,
                  onTap: () => widget.onCancel(appt),
                ),
            ],
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
