class ServiceModel {
  final int servicioId;
  final int establecimientoId;
  final String nombre;
  final String descripcion;
  final int duracion; // minutos
  final double precio;
  final bool activo;

  ServiceModel({
    required this.servicioId,
    required this.establecimientoId,
    required this.nombre,
    required this.descripcion,
    required this.duracion,
    required this.precio,
    required this.activo,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    // precio puede venir como String o num desde la API
    final rawPrecio = json['precio'];
    double parsedPrecio;
    if (rawPrecio is num) {
      parsedPrecio = rawPrecio.toDouble();
    } else if (rawPrecio is String) {
      parsedPrecio = double.tryParse(rawPrecio) ?? 0.0;
    } else {
      parsedPrecio = 0.0;
    }

    return ServiceModel(
      servicioId: json['servicio_id'] as int,
      establecimientoId: json['establecimiento_id'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      duracion: json['duracion'] as int? ?? 0,
      precio: parsedPrecio,
      activo: json['activo'] as bool? ?? true,
    );
  }

  /// Alias para mantener compatibilidad
  int get duracionMin => duracion;

  /// Precio formateado para la UI
  String get precioFormateado => '\$${precio.toStringAsFixed(2)}';

  /// Duración formateada
  String get duracionFormateada {
    if (duracion >= 60) {
      final h = duracion ~/ 60;
      final m = duracion % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }
    return '$duracion min';
  }
}
