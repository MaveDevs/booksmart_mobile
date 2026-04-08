class RatingModel {
  final int resenaId;
  final int establecimientoId;
  final int usuarioId;
  final int calificacion;
  final String comentario;
  final DateTime fecha;

  RatingModel({
    required this.resenaId,
    required this.establecimientoId,
    required this.usuarioId,
    required this.calificacion,
    required this.comentario,
    required this.fecha,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      resenaId: json['resena_id'] as int,
      establecimientoId: json['establecimiento_id'] as int,
      usuarioId: json['usuario_id'] as int,
      calificacion: json['calificacion'] as int? ?? 0,
      comentario: json['comentario'] as String? ?? '',
      fecha: DateTime.tryParse(json['fecha'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
