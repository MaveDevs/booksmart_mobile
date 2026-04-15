class WorkerModel {
  final int trabajadorId;
  final int establecimientoId;
  final String nombre;
  final String apellido;
  final String? email;
  final String? telefono;
  final String? fotoPerfil;
  final String? especialidad;
  final String? descripcion;
  final bool activo;

  WorkerModel({
    required this.trabajadorId,
    required this.establecimientoId,
    required this.nombre,
    required this.apellido,
    this.email,
    this.telefono,
    this.fotoPerfil,
    this.especialidad,
    this.descripcion,
    required this.activo,
  });

  factory WorkerModel.fromJson(Map<String, dynamic> json) {
    return WorkerModel(
      trabajadorId: json['trabajador_id'] as int,
      establecimientoId: json['establecimiento_id'] as int,
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      email: json['email'] as String?,
      telefono: json['telefono'] as String?,
      fotoPerfil: json['foto_perfil'] as String?,
      especialidad: json['especialidad'] as String?,
      descripcion: json['descripcion'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  String get nombreCompleto => '$nombre $apellido'.trim();
}
