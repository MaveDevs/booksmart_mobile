import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          home: const AuthChecker(),
        );
      },
    );
  }
}

/// Widget que verifica si hay una sesion activa
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final hasToken = await StorageService.hasToken();
    if (hasToken) {
      // Si hay token pero no hay userId guardado, obtenerlo
      final userId = await StorageService.getUserId();
      if (userId == null) {
        final userResult = await ApiService.getCurrentUser();
        if (userResult.success && userResult.data != null) {
          await StorageService.saveUserId(userResult.data!.usuarioId);
        }
      }
      // Conectar WebSocket y escuchar notificaciones
      await WebSocketService.instance.connect();
      LocalNotificationService.startListening();
    }
    setState(() {
      _isLoggedIn = hasToken;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    return _isLoggedIn ? const MainScreen() : const LoginScreen();
  }
}
