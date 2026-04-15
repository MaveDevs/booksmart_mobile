import 'dart:math';

class EstablishmentModel {
  final int establecimientoId;
  final String nombre;
  final String descripcion;
  final String direccion;
  final double latitud;
  final double longitud;
  final String telefono;
  final int usuarioId;
  final bool activo;
  // Campos del endpoint nearby
  final double? distanceKm;
  final double? rankingScore;
  final bool? subscriptionActive;
  final String? subscriptionPlanName;

  EstablishmentModel({
    required this.establecimientoId,
    required this.nombre,
    required this.descripcion,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.telefono,
    required this.usuarioId,
    required this.activo,
    this.distanceKm,
    this.rankingScore,
    this.subscriptionActive,
    this.subscriptionPlanName,
  });

  factory EstablishmentModel.fromJson(Map<String, dynamic> json) {
    return EstablishmentModel(
      establecimientoId: json['establecimiento_id'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      direccion: json['direccion'] as String? ?? '',
      latitud: (json['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (json['longitud'] as num?)?.toDouble() ?? 0.0,
      telefono: json['telefono'] as String? ?? '',
      usuarioId: json['usuario_id'] as int? ?? 0,
      activo: json['activo'] as bool? ?? true,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      rankingScore: (json['ranking_score'] as num?)?.toDouble(),
      subscriptionActive: json['subscription_active'] as bool?,
      subscriptionPlanName: json['subscription_plan_name'] as String?,
    );
  }

  /// Calcula la distancia en km entre este establecimiento y una ubicación
  /// usando la fórmula de Haversine
  double distanceTo(double userLat, double userLon) {
    const R = 6371.0; // Radio de la Tierra en km
    final dLat = _toRad(latitud - userLat);
    final dLon = _toRad(longitud - userLon);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(userLat)) * cos(_toRad(latitud)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180;

  /// Distancia formateada para mostrar en la UI
  /// Usa distanceKm del backend si está disponible, sino calcula con Haversine
  String distanciaFormateada(double userLat, double userLon) {
    final dist = distanceKm ?? distanceTo(userLat, userLon);
    if (dist < 1) {
      return '${(dist * 1000).round()} m';
    }
    return '${dist.toStringAsFixed(1)} km';
  }
}
