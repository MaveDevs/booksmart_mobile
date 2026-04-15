import 'package:flutter/material.dart';
import '../config/page_transitions.dart';
import '../services/websocket_service.dart';
import 'notifications_screen.dart';
import 'tabs/search_tab.dart';
import 'tabs/appointments_tab.dart';
import 'tabs/profile_tab.dart';

/// Pantalla principal con navegacion flotante
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _hideNotificationBell = false;
  final _searchTabKey = GlobalKey<SearchTabState>();

  late final List<Widget> _tabs = [
    SearchTab(
      key: _searchTabKey,
      onMapChanged: (isMap) => setState(() => _hideNotificationBell = isMap),
    ),
    const AppointmentsTab(),
    const ProfileTab(),
  ];

  final List<_NavItemData> _navItems = const [
    _NavItemData(icon: Icons.search_rounded, label: 'Buscar'),
    _NavItemData(icon: Icons.calendar_today_rounded, label: 'Citas'),
    _NavItemData(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    // Asegurar que el polling de notificaciones esté activo
    WebSocketService.instance.startNotificationPolling();
    debugPrint('[MainScreen] initState — polling iniciado');
  }

  void _openNotifications() {
    Navigator.push(
      context,
      appRoute(const NotificationsScreen()),
    ).then((result) {
      // Al volver, recargar conteo real desde API
      WebSocketService.instance.refreshUnreadCount();
      // Si la notificación pidió navegar a Citas, cambiar de pestaña
      if (result == 'appointments') {
        setState(() => _currentIndex = 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Leemos del ThemeData para que el rebuild ocurra al cambiar tema
    final theme = Theme.of(context);
    final navSurface = theme.colorScheme.surface;
    final navPrimary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final navInactive = isDark ? const Color(0xFF9CB0CC) : const Color(0xFF64748B);

    return Scaffold(
      body: Stack(
        children: [
          _tabs[_currentIndex],
          // Botón de notificaciones flotante
          if (!_hideNotificationBell) Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: ValueListenableBuilder<int>(
                valueListenable: WebSocketService.instance.unreadCount,
                builder: (_, count, __) {
                  return GestureDetector(
                    onTap: _openNotifications,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: navInactive,
                            size: 22,
                          ),
                          if (count > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    count > 9 ? '9+' : '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        height: 70,
        decoration: BoxDecoration(
          color: navSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 3;
              return Stack(
                children: [
                  // Highlight deslizante con padding y bordes redondeados
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    left: _currentIndex * itemWidth + 8,
                    top: 8,
                    bottom: 8,
                    width: itemWidth - 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: navPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  // Items de navegacion
                  Row(
                    children: List.generate(
                      _navItems.length,
                      (index) => _NavItem(
                        icon: _navItems[index].icon,
                        label: _navItems[index].label,
                        isSelected: _currentIndex == index,
                        activeColor: navPrimary,
                        inactiveColor: navInactive,
                        onTap: () {
                          if (index == 0 && _currentIndex == 0) {
                            // Re-tap en Buscar: volver al inicio
                            Navigator.of(context).popUntil((r) => r.isFirst);
                            _searchTabKey.currentState?.goHome();
                          } else {
                            setState(() => _currentIndex = index);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Datos de un item de navegacion
class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}

/// Item individual del menu de navegacion
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: isSelected
                ? Row(
                    key: const ValueKey('selected'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: activeColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: activeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Icon(
                    key: const ValueKey('unselected'),
                    icon,
                    color: inactiveColor,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}
