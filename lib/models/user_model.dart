/// Modelo de usuario que representa los datos del usuario
class UserModel {
  final int usuarioId;
  final String nombre;
  final String apellido;
  final String correo;
  final int rolId;
  final bool activo;
  final DateTime fechaCreacion;

  UserModel({
    required this.usuarioId,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.rolId,
    required this.activo,
    required this.fechaCreacion,
  });

  /// Crea un UserModel desde un Map (JSON)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      usuarioId: json['usuario_id'] as int,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      correo: json['correo'] as String,
      rolId: json['rol_id'] as int,
      activo: json['activo'] as bool,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
    );
  }

  /// Convierte el modelo a Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'usuario_id': usuarioId,
      'nombre': nombre,
      'apellido': apellido,
      'correo': correo,
      'rol_id': rolId,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  /// Nombre completo del usuario
  String get nombreCompleto => '$nombre $apellido';
}
