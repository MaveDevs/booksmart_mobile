import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';
import 'services/background_service.dart';
import 'services/local_notification_service.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'services/websocket_service.dart';

/// Clave global del Navigator para navegación programática (ej. 401 redirect)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.init();
  await LocalNotificationService.init();
  await BackgroundService.init();

  // Verificar token ANTES de runApp para evitar pantalla de carga intermedia
  final hasToken = await StorageService.hasToken();

  runApp(MyApp(isLoggedIn: hasToken));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (_, themeMode, __) {
        return MaterialApp(
          title: 'BookSmart',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            AppColors.updateBrightness(
                Theme.of(context).brightness == Brightness.dark);
            return child!;
          },
          home: isLoggedIn ? const _PostLoginInit() : const LoginScreen(),
        );
      },
    );
  }
}

/// Inicia servicios en background y muestra MainScreen directamente
class _PostLoginInit extends StatefulWidget {
  const _PostLoginInit();

  @override
  State<_PostLoginInit> createState() => _PostLoginInitState();
}

class _PostLoginInitState extends State<_PostLoginInit> {
  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    // Obtener userId si falta
    final userId = await StorageService.getUserId();
    if (userId == null) {
      final userResult = await ApiService.getCurrentUser();
      if (userResult.success && userResult.data != null) {
        await StorageService.saveUserId(userResult.data!.usuarioId);
      }
    }
    // Conectar WebSocket y notificaciones en background
    await WebSocketService.instance.connect();
    LocalNotificationService.startListening();
    // Registrar tarea en background para notificaciones con app cerrada
    await BackgroundService.startPeriodicCheck();
  }

  @override
  Widget build(BuildContext context) => const MainScreen();
}
