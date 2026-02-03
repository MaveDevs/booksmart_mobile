import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Tab de citas agendadas
class AppointmentsTab extends StatelessWidget {
  const AppointmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Datos de ejemplo (despues se conectara a la API)
    final appointments = <Map<String, dynamic>>[
      {
        'establecimiento': 'Barberia Classic',
        'servicio': 'Corte de cabello',
        'fecha': '15 Feb 2026',
        'hora': '10:30 AM',
        'estado': 'aprobada',
      },
      {
        'establecimiento': 'Salon Beauty',
        'servicio': 'Manicure',
        'fecha': '18 Feb 2026',
        'hora': '3:00 PM',
        'estado': 'pendiente',
      },
    ];

    return Scaffold(
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

            // Lista de citas
            Expanded(
              child: appointments.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        return _AppointmentCard(
                          appointment: appointments[index],
                        );
                      },
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
          const Text(
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
}

/// Card de una cita
class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final isApproved = appointment['estado'] == 'aprobada';

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
          // Establecimiento y estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  appointment['establecimiento'],
                  style: const TextStyle(
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
                  color: isApproved
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.pending.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved
                          ? Icons.check_circle_outline
                          : Icons.schedule_outlined,
                      size: 14,
                      color: isApproved ? AppColors.success : AppColors.pending,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isApproved ? 'Aprobada' : 'Pendiente',
                      style: TextStyle(
                        color:
                            isApproved ? AppColors.success : AppColors.pending,
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
              const Icon(
                Icons.content_cut_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                appointment['servicio'],
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fecha y hora
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: 8),
              Text(
                '${appointment['fecha']} - ${appointment['hora']}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
