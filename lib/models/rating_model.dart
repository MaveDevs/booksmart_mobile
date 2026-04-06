class RatingModel {
  final int calificacionId;
  final int establecimientoId;
  final int usuarioId;
  final int puntuacion;
  final String comentario;
  final DateTime fecha;

  RatingModel({
    required this.calificacionId,
    required this.establecimientoId,
    required this.usuarioId,
    required this.puntuacion,
    required this.comentario,
    required this.fecha,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      calificacionId: json['calificacion_id'] as int,
      establecimientoId: json['establecimiento_id'] as int,
      usuarioId: json['usuario_id'] as int,
      puntuacion: json['puntuacion'] as int? ?? 0,
      comentario: json['comentario'] as String? ?? '',
      fecha: DateTime.tryParse(json['fecha'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
