# BookSmart

Aplicación móvil para agendar citas en establecimientos de belleza y bienestar (estéticas, barberías, spas, etc.).

## Características

- **Autenticación** — Registro e inicio de sesión con JWT
- **Explorar establecimientos** — Búsqueda con mapa interactivo (OpenStreetMap) y geolocalización
- **Detalle de establecimiento** — Vista estilo Uber Eats con servicios, horarios y ubicación
- **Agendar citas** — Selección de servicio, fecha y hora disponible
- **Mis citas** — Visualización de citas pendientes, aceptadas y completadas
- **Chat** — Mensajería en tiempo real entre cliente y establecimiento
- **Notificaciones** — Sistema de notificaciones con WebSocket y polling (en desarrollo)
- **Perfil** — Edición de datos personales y foto de perfil
- **Tema claro/oscuro** — Material Design 3 con soporte dual

## Tecnologías

| Categoría | Tecnología |
|-----------|-----------|
| Framework | Flutter (Dart) |
| Backend | FastAPI (Python) |
| Autenticación | JWT + flutter_secure_storage |
| Mapas | flutter_map + OpenStreetMap |
| Ubicación | Geolocator |
| Tiempo real | WebSocket (web_socket_channel) |
| Notificaciones | flutter_local_notifications |
| CI/CD | GitHub Actions |

## Requisitos

- Flutter SDK ^3.10.8
- Java 17 (para compilar Android)
- Dispositivo Android o emulador

## Instalación

```bash
# Clonar el repositorio
git clone git@github.com:MaveDevs/booksmart_mobile.git
cd booksmart_mobile

# Instalar dependencias
flutter pub get

# Ejecutar en modo debug
flutter run
```

## Estructura del proyecto

```
lib/
├── main.dart                 # Punto de entrada
├── config/                   # Configuración (API, tema)
├── models/                   # Modelos de datos
├── screens/                  # Pantallas de la app
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── main_screen.dart
│   ├── establishment_detail_screen.dart
│   ├── booking_screen.dart
│   ├── appointment_chat_screen.dart
│   ├── notifications_screen.dart
│   └── tabs/                 # Pestañas principales
│       ├── search_tab.dart
│       ├── appointments_tab.dart
│       └── profile_tab.dart
└── services/                 # Servicios (API, WebSocket, notificaciones)
```

## CI/CD

El proyecto cuenta con un pipeline de GitHub Actions. Consulta [README_DEVOPS.md](README_DEVOPS.md) para más detalles.

## Equipo

**MaveDevs** — Universidad Tecnológica de Tijuana
