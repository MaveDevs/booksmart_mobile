/// Configuracion de la API
/// 
/// Para encontrar tu IP local:
/// - Linux/Mac: ifconfig o ip addr
/// - Windows: ipconfig
/// 
class ApiConfig {
  // Cambia esta IP por la de tu computadora en tu red local
  static const String baseUrl = 'https://booksmartutt.duckdns.org';
  
  // Endpoints de autenticacion
  static const String loginEndpoint = '/api/v1/auth/login/access-token';
  static const String registerEndpoint = '/api/v1/users/';
  static const String userEndpoint = '/api/v1/users';
  
  // Timeout para las peticiones (en segundos)
  static const int timeout = 30;
}
