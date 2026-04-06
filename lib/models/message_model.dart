class MessageModel {
  final int? mensajeId;
  final int citaId;
  final int emisorId;
  final String contenido;
  final String? fechaEnvio;

  MessageModel({
    this.mensajeId,
    required this.citaId,
    required this.emisorId,
    required this.contenido,
    this.fechaEnvio,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      mensajeId: json['mensaje_id'] as int?,
      citaId: json['cita_id'] as int,
      emisorId: json['emisor_id'] as int,
      contenido: json['contenido'] as String? ?? '',
      fechaEnvio: json['fecha_envio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cita_id': citaId,
      'emisor_id': emisorId,
      'contenido': contenido,
    };
  }

  /// True si este mensaje fue enviado por el usuario dado
  bool isMine(int userId) => emisorId == userId;
}
