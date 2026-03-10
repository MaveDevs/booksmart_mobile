import 'package:geolocator/geolocator.dart';

/// Servicio para obtener la ubicación del dispositivo
class LocationService {
  /// Obtiene la ubicación actual del usuario
  /// Solicita permisos si es necesario
  static Future<Position?> getCurrentLocation() async {
    // Verifica si el servicio de ubicación está activo
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Verifica permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Obtiene la ubicación actual
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Verifica si tiene permisos de ubicación
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
