class NotificationModel {
  final int notificacionId;
  final int usuarioId;
  final String tipo; // mensaje, cita_confirmada, cita_cancelada, etc.
  final String contenido;
  final bool leida;
  final String? fechaCreacion;
  final int? citaId;

  NotificationModel({
    required this.notificacionId,
    required this.usuarioId,
    required this.tipo,
    required this.contenido,
    required this.leida,
    this.fechaCreacion,
    this.citaId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificacionId: json['notificacion_id'] as int? ?? json['id'] as int? ?? 0,
      usuarioId: json['usuario_id'] as int? ?? 0,
      tipo: json['tipo'] as String? ?? '',
      contenido: json['contenido'] as String? ?? '',
      leida: json['leida'] as bool? ?? false,
      fechaCreacion: json['fecha_creacion'] as String?,
      citaId: json['cita_id'] as int?,
    );
  }
}
