class AppointmentModel {
  final int citaId;
  final int clienteId;
  final int servicioId;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final String estado; // PENDIENTE, CONFIRMADA, CANCELADA, COMPLETADA

  // Campos opcionales que pueden venir con la relación expandida
  final String? servicioNombre;
  final String? establecimientoNombre;
  final int? establecimientoId;
  final int? trabajadorId;
  final String? trabajadorNombre;
  final String? trabajadorApellido;

  AppointmentModel({
    required this.citaId,
    required this.clienteId,
    required this.servicioId,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
    this.servicioNombre,
    this.establecimientoNombre,
    this.establecimientoId,
    this.trabajadorId,
    this.trabajadorNombre,
    this.trabajadorApellido,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      citaId: json['cita_id'] as int,
      clienteId: json['cliente_id'] as int,
      servicioId: json['servicio_id'] as int,
      fecha: json['fecha'] as String? ?? '',
      horaInicio: json['hora_inicio'] as String? ?? '',
      horaFin: json['hora_fin'] as String? ?? '',
      estado: json['estado'] as String? ?? 'PENDIENTE',
      servicioNombre: json['servicio_nombre'] as String?,
      establecimientoNombre: json['establecimiento_nombre'] as String?,
      establecimientoId: json['establecimiento_id'] as int?,
      trabajadorId: json['trabajador_id'] as int?,
      trabajadorNombre: json['trabajador_nombre'] as String?,
      trabajadorApellido: json['trabajador_apellido'] as String?,
    );
  }

  bool get isPendiente => estado == 'PENDIENTE';
  bool get isConfirmada => estado == 'CONFIRMADA';
  bool get isCancelada => estado == 'CANCELADA';
  bool get isCompletada => estado == 'COMPLETADA';

  /// Si la cita se puede cancelar (solo PENDIENTE o CONFIRMADA)
  bool get canCancel => isPendiente || isConfirmada;

  String get estadoDisplay {
    switch (estado) {
      case 'PENDIENTE':
        return 'Pendiente';
      case 'CONFIRMADA':
        return 'Confirmada';
      case 'CANCELADA':
        return 'Cancelada';
      case 'COMPLETADA':
        return 'Completada';
      default:
        return estado;
    }
  }

  /// Nombre completo del trabajador asignado
  String? get trabajadorNombreCompleto {
    if (trabajadorNombre == null) return null;
    final parts = <String>[
      if (trabajadorNombre != null && trabajadorNombre!.isNotEmpty) trabajadorNombre!,
      if (trabajadorApellido != null && trabajadorApellido!.isNotEmpty) trabajadorApellido!,
    ];
    return parts.isNotEmpty ? parts.join(' ') : null;
  }

  /// Hora formateada: "10:30 - 11:00"
  String get horarioDisplay => '$horaInicio - $horaFin';
}
